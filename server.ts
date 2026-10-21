import express, { Request, Response, NextFunction } from 'express';
import path from 'path';
import fs from 'fs';
import { createServer as createViteServer } from 'vite';
import { db } from './src/server/db';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;
const isProd = process.env.NODE_ENV === 'production';

// Ensure public/uploads directory exists
const PUBLIC_DIR = path.resolve(process.cwd(), 'public');
const UPLOADS_DIR = path.resolve(PUBLIC_DIR, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// Enable JSON body parsing with generous limit for image uploads
app.use(express.json({ limit: '25mb' }));
app.use(express.urlencoded({ extended: true, limit: '25mb' }));

// Serve uploaded user images and public downloads
app.use('/uploads', express.static(UPLOADS_DIR));
app.use('/downloads', express.static(path.resolve(PUBLIC_DIR, 'downloads')));

// Direct ZIP download route
app.get('/api/download/zip', (_req: Request, res: Response) => {
  const zipPath = path.resolve(process.cwd(), 'public/downloads/gadgethub-source.zip');
  if (fs.existsSync(zipPath)) {
    res.download(zipPath, 'gadgethub-source.zip');
  } else {
    res.status(404).json({ error: 'Source archive not found' });
  }
});

// Direct schema.sql text & download route
app.get('/schema.sql', (_req: Request, res: Response) => {
  const schemaPath = path.resolve(process.cwd(), 'schema.sql');
  if (fs.existsSync(schemaPath)) {
    res.type('text/plain').sendFile(schemaPath);
  } else {
    res.status(404).send('schema.sql not found');
  }
});

app.get('/api/schema', (_req: Request, res: Response) => {
  const schemaPath = path.resolve(process.cwd(), 'schema.sql');
  if (fs.existsSync(schemaPath)) {
    res.type('text/plain').sendFile(schemaPath);
  } else {
    res.status(404).json({ error: 'schema.sql not found' });
  }
});

app.get('/api/schema/download', (_req: Request, res: Response) => {
  const schemaPath = path.resolve(process.cwd(), 'schema.sql');
  if (fs.existsSync(schemaPath)) {
    res.download(schemaPath, 'schema.sql', {
      headers: {
        'Content-Type': 'application/sql',
      },
    });
  } else {
    res.status(404).json({ error: 'schema.sql not found' });
  }
});

// Admin Authentication Middleware
const requireAdmin = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  const adminTokenHeader = req.headers['x-admin-token'] as string;
  let token = '';

  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7).trim();
  } else if (adminTokenHeader) {
    token = adminTokenHeader.trim();
  }

  if (!token || !db.verifyAdminToken(token)) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Valid administrator token required for this action',
    });
  }

  next();
};

// ==========================================
// REST API ROUTES (/api/*)
// ==========================================

// 1. Health & Database Status
app.get('/api/health', async (_req: Request, res: Response) => {
  try {
    const dbStatus = await db.getDbStatus();
    res.json({
      status: 'ok',
      app: 'Gadgethub E-Commerce Platform',
      timestamp: new Date().toISOString(),
      database: dbStatus,
    });
  } catch (err: any) {
    res.status(500).json({
      status: 'error',
      error: err?.message || 'Failed fetching database status',
    });
  }
});

// 2. Admin Authentication
app.get('/api/admin/auth-status', (_req: Request, res: Response) => {
  const authConfig = db.getAdminAuthConfig();
  res.json({
    configured: authConfig.isConfigured,
    error: authConfig.error || null,
  });
});

app.post('/api/admin/login', (req: Request, res: Response) => {
  const { password } = req.body;
  if (!password) {
    return res.status(400).json({ error: 'Password is required' });
  }

  const result = db.authenticateAdmin(password);
  if (result.success && result.token) {
    return res.json({
      success: true,
      token: result.token,
      message: 'Administrator session authenticated',
    });
  }

  return res.status(result.status || 401).json({
    success: false,
    error: result.error || 'Invalid administrator password',
  });
});

app.get('/api/admin/verify', (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7) : '';
  const isValid = db.verifyAdminToken(token);
  res.json({ valid: isValid });
});

app.post('/api/admin/logout', (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7) : '';
  if (token) {
    db.revokeAdminToken(token);
  }
  res.json({ success: true });
});

// 3. Products
app.get('/api/products', (_req: Request, res: Response) => {
  const products = db.getProducts();
  res.json(products);
});

app.get('/api/products/:id', (req: Request, res: Response) => {
  const product = db.getProductById(req.params.id);
  if (!product) {
    return res.status(404).json({ error: 'Product not found' });
  }
  res.json(product);
});

app.post('/api/products', requireAdmin, (req: Request, res: Response) => {
  try {
    const { title, category, brand, price } = req.body;
    if (!title || !price || !brand) {
      return res.status(400).json({ error: 'Title, brand, and price are required' });
    }

    const created = db.addProduct(req.body);
    res.status(201).json(created);
  } catch (err) {
    console.error('Error adding product:', err);
    res.status(500).json({ error: 'Failed to create product' });
  }
});

app.put('/api/products/:id', requireAdmin, (req: Request, res: Response) => {
  try {
    const updated = db.updateProduct(req.params.id, req.body);
    if (!updated) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json(updated);
  } catch (err) {
    console.error('Error updating product:', err);
    res.status(500).json({ error: 'Failed to update product' });
  }
});

app.delete('/api/products/:id', requireAdmin, (req: Request, res: Response) => {
  const success = db.deleteProduct(req.params.id);
  if (!success) {
    return res.status(404).json({ error: 'Product not found' });
  }
  res.json({ success: true, message: 'Product deleted successfully' });
});

// 4. Categories
app.get('/api/categories', (_req: Request, res: Response) => {
  res.json(db.getCategories());
});

app.post('/api/categories', requireAdmin, (req: Request, res: Response) => {
  const { name, iconName } = req.body;
  if (!name) {
    return res.status(400).json({ error: 'Category name is required' });
  }
  const id = req.body.id || name.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const cat = db.addCategory({
    id,
    name,
    slug: id,
    iconName: iconName || 'Smartphone',
    description: req.body.description || '',
    itemCount: 0,
  });
  res.status(201).json(cat);
});

// 5. Orders (with server-side validation and Supabase cloud persistence)
app.get('/api/orders', (_req: Request, res: Response) => {
  res.json(db.getOrders());
});

app.get('/api/orders/:id', (req: Request, res: Response) => {
  const order = db.getOrderByIdOrTracking(req.params.id);
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }
  res.json(order);
});

app.post('/api/orders', async (req: Request, res: Response) => {
  try {
    const order = await db.createValidatedOrder(req.body);
    res.status(201).json(order);
  } catch (err: any) {
    console.error('Order creation error:', err?.message || err);
    res.status(400).json({
      error: err?.message || 'Failed to place order due to validation error.',
    });
  }
});

app.put('/api/orders/:id/status', requireAdmin, (req: Request, res: Response) => {
  const { status } = req.body;
  if (!status) {
    return res.status(400).json({ error: 'Status is required' });
  }

  const updated = db.updateOrderStatus(req.params.id, status);
  if (!updated) {
    return res.status(404).json({ error: 'Order not found' });
  }

  res.json(updated);
});

app.delete('/api/orders/:id', requireAdmin, (req: Request, res: Response) => {
  const success = db.deleteOrder(req.params.id);
  if (!success) {
    return res.status(404).json({ error: 'Order not found' });
  }
  res.json({ success: true, message: 'Order deleted successfully' });
});

// Retry Email / WhatsApp notification for an order
app.post('/api/orders/:id/retry-notification', requireAdmin, async (req: Request, res: Response) => {
  const channel = req.body.channel || 'all';
  const result = await db.retryNotification(req.params.id, channel);
  if (!result.success) {
    return res.status(404).json({ error: result.error || 'Failed to retry notification' });
  }
  res.json({ success: true, order: result.order });
});

// Trigger manual Supabase sync
app.post('/api/db/sync', requireAdmin, async (_req: Request, res: Response) => {
  try {
    await db.syncWithSupabase();
    res.json({ success: true, message: 'Catalog synchronized with Supabase database.' });
  } catch (err: any) {
    res.status(500).json({ error: err?.message || 'Failed to synchronize with Supabase' });
  }
});

// 6. Image Uploads (Base64 / Data URL to local static file)
app.post('/api/upload', (req: Request, res: Response) => {
  try {
    const { imageBase64, filename } = req.body;
    if (!imageBase64) {
      return res.status(400).json({ error: 'imageBase64 is required' });
    }

    // Match base64 data format: data:image/png;base64,....
    const matches = imageBase64.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
    if (!matches || matches.length !== 3) {
      // If it's already a full URL, return it
      if (imageBase64.startsWith('http://') || imageBase64.startsWith('https://') || imageBase64.startsWith('/')) {
        return res.json({ url: imageBase64 });
      }
      return res.status(400).json({ error: 'Invalid base64 image data' });
    }

    const ext = matches[1].split('/')[1] || 'jpg';
    const cleanExt = ext === 'jpeg' ? 'jpg' : ext;
    const safeName = filename
      ? `${filename.replace(/[^a-zA-Z0-9_-]/g, '_')}_${Date.now()}.${cleanExt}`
      : `gadget_${Date.now()}.${cleanExt}`;

    const filePath = path.join(UPLOADS_DIR, safeName);
    const buffer = Buffer.from(matches[2], 'base64');
    fs.writeFileSync(filePath, buffer);

    res.json({
      url: `/uploads/${safeName}`,
      success: true,
    });
  } catch (err) {
    console.error('Upload failed:', err);
    res.status(500).json({ error: 'Failed to upload image' });
  }
});

// 7. Reset DB to Default Data
app.post('/api/db/reset', requireAdmin, (_req: Request, res: Response) => {
  db.resetToDefaults();
  res.json({ success: true, message: 'Database reset to default products and orders' });
});

// ==========================================
// VITE DEV SERVER OR STATIC PRODUCTION
// ==========================================

async function startServer() {
  if (!isProd) {
    // Development mode with Vite middleware
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });

    app.use(vite.middlewares);
  } else {
    // Production mode
    const distPath = path.resolve(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (_req: Request, res: Response) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Gadgethub Server] Running on http://0.0.0.0:${PORT}`);
  });
}

startServer().catch((err) => {
  console.error('Server start error:', err);
});
