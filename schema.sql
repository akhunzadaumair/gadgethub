-- ====================================================================
-- GADGETHUB - Complete Supabase / PostgreSQL Database Schema
-- ====================================================================
-- Run this script in your Supabase SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Paste & Click "Run"
-- ====================================================================

-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================================================
-- 1. Automatic Timestamp Update Function
-- ====================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 2. Categories Table
-- ====================================================================
CREATE TABLE IF NOT EXISTS categories (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  icon_name VARCHAR(64) NOT NULL DEFAULT 'Smartphone',
  description TEXT,
  item_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for categories updated_at
DROP TRIGGER IF EXISTS trigger_categories_updated_at ON categories;
CREATE TRIGGER trigger_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- ====================================================================
-- 3. Products Table
-- ====================================================================
CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL,
  category VARCHAR(128) NOT NULL,
  category_id VARCHAR(64) REFERENCES categories(id) ON DELETE SET NULL,
  brand VARCHAR(128) NOT NULL,
  price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
  original_price NUMERIC(12, 2) CHECK (original_price >= 0),
  discount_percent INTEGER DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  rating NUMERIC(3, 2) DEFAULT 5.0 CHECK (rating >= 0 AND rating <= 5),
  review_count INTEGER DEFAULT 0 CHECK (review_count >= 0),
  images TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  description TEXT,
  specs JSONB DEFAULT '{}'::jsonb,
  is_featured BOOLEAN DEFAULT FALSE,
  is_best_seller BOOLEAN DEFAULT FALSE,
  is_new_arrival BOOLEAN DEFAULT FALSE,
  is_trade_assurance BOOLEAN DEFAULT TRUE,
  moq INTEGER DEFAULT 1 CHECK (moq >= 1),
  wholesale_price NUMERIC(12, 2) CHECK (wholesale_price >= 0),
  sku VARCHAR(64) UNIQUE,
  warranty VARCHAR(128) DEFAULT '1 Year Official Warranty',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for products updated_at
DROP TRIGGER IF EXISTS trigger_products_updated_at ON products;
CREATE TRIGGER trigger_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
CREATE INDEX IF NOT EXISTS idx_products_is_featured ON products(is_featured);
CREATE INDEX IF NOT EXISTS idx_products_is_best_seller ON products(is_best_seller);
CREATE INDEX IF NOT EXISTS idx_products_is_new_arrival ON products(is_new_arrival);
CREATE INDEX IF NOT EXISTS idx_products_stock ON products(stock);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);

-- ====================================================================
-- 4. Customer Orders Table
-- ====================================================================
CREATE TABLE IF NOT EXISTS orders (
  id VARCHAR(64) PRIMARY KEY, -- e.g. GH-PK-89211
  date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  customer JSONB NOT NULL,    -- { fullName, email, phone, address, city, province, postalCode, orderNotes }
  items JSONB NOT NULL,       -- Array of { product, quantity, selectedColor, selectedVariant }
  subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
  shipping_fee NUMERIC(12, 2) DEFAULT 0 CHECK (shipping_fee >= 0),
  discount NUMERIC(12, 2) DEFAULT 0 CHECK (discount >= 0),
  total NUMERIC(12, 2) NOT NULL CHECK (total >= 0),
  payment_method VARCHAR(32) NOT NULL DEFAULT 'cod',
  status VARCHAR(32) NOT NULL DEFAULT 'Pending',
  tracking_number VARCHAR(64),
  courier_name VARCHAR(64) DEFAULT 'TCS Express Pakistan',
  notifications JSONB DEFAULT '{"email": {"status": "pending"}, "whatsapp": {"status": "pending"}}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Upgrade column if table already exists
ALTER TABLE orders ADD COLUMN IF NOT EXISTS notifications JSONB DEFAULT '{"email": {"status": "pending"}, "whatsapp": {"status": "pending"}}'::jsonb;

-- Trigger for orders updated_at
DROP TRIGGER IF EXISTS trigger_orders_updated_at ON orders;
CREATE TRIGGER trigger_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Indexes for orders
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_tracking_number ON orders(tracking_number);
CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(date DESC);
CREATE INDEX IF NOT EXISTS idx_orders_customer_email ON orders USING btree ((customer->>'email'));
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON orders USING btree ((customer->>'phone'));

-- ====================================================================
-- 5. Row Level Security (RLS) Configuration
-- ====================================================================
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------
-- Categories RLS Policies
-- --------------------------------------------------------------------
-- Anyone can view categories
DROP POLICY IF EXISTS "Public categories read access" ON categories;
CREATE POLICY "Public categories read access"
  ON categories FOR SELECT
  USING (true);

-- Only authenticated backend / service_role can manage categories
DROP POLICY IF EXISTS "Service role category management" ON categories;
CREATE POLICY "Service role category management"
  ON categories FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- --------------------------------------------------------------------
-- Products RLS Policies
-- --------------------------------------------------------------------
-- Anyone can view products
DROP POLICY IF EXISTS "Public products read access" ON products;
CREATE POLICY "Public products read access"
  ON products FOR SELECT
  USING (true);

-- Only authenticated backend / service_role can add, update, or delete products
DROP POLICY IF EXISTS "Service role product management" ON products;
CREATE POLICY "Service role product management"
  ON products FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- --------------------------------------------------------------------
-- Orders RLS Policies
-- --------------------------------------------------------------------
-- Customers can insert their own orders during checkout
DROP POLICY IF EXISTS "Public insert orders" ON orders;
CREATE POLICY "Public insert orders"
  ON orders FOR INSERT
  WITH CHECK (true);

-- Customers can view their own orders if authenticated with matching email
-- Or service_role has full visibility over all orders for store management
DROP POLICY IF EXISTS "Customer and admin read orders" ON orders;
CREATE POLICY "Customer and admin read orders"
  ON orders FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    (auth.jwt() IS NOT NULL AND customer->>'email' = auth.jwt()->>'email')
  );

-- Only service_role / store admin can update delivery and payment statuses
DROP POLICY IF EXISTS "Service role order update" ON orders;
CREATE POLICY "Service role order update"
  ON orders FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Only service_role can delete orders
DROP POLICY IF EXISTS "Service role order delete" ON orders;
CREATE POLICY "Service role order delete"
  ON orders FOR DELETE
  USING (auth.role() = 'service_role');

-- ====================================================================
-- 6. Initial Seed Data (Categories & Catalog)
-- ====================================================================

-- Insert Initial Categories
INSERT INTO categories (id, name, slug, icon_name, description, item_count)
VALUES
  ('mobiles', 'Mobile Phones', 'mobiles', 'Smartphone', 'PTA Approved Flagship & Budget Smartphones', 8),
  ('audio', 'Audio & Sound', 'audio', 'Headphones', 'Noise Cancelling Headphones & True Wireless Earbuds', 6),
  ('wearables', 'Smartwatches', 'wearables', 'Watch', 'Fitness Trackers, Cellular & Ultra Smartwatches', 5),
  ('computers', 'Computers & Laptops', 'computers', 'Laptop', 'MacBooks, Gaming Rigs & Workstations', 4),
  ('accessories', 'Accessories & Chargers', 'accessories', 'Zap', 'Fast GaN Chargers, Braided Cables & Power Banks', 9),
  ('home-appliances', 'Smart Home Appliances', 'home-appliances', 'Home', 'Robot Vacuums, Air Purifiers & Smart Lighting', 4),
  ('gaming', 'Gaming & Consoles', 'gaming', 'Gamepad2', 'Controllers, Mechanical Keyboards & VR Headsets', 5),
  ('fashion-tech', 'Tech Lifestyle & Travel', 'fashion-tech', 'Backpack', 'Waterproof Laptop Backpacks & EDC Tech Organizers', 3)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  icon_name = EXCLUDED.icon_name,
  description = EXCLUDED.description;

-- Insert Flagship Demo Products
INSERT INTO products (
  id, title, slug, category, category_id, brand, price, original_price,
  discount_percent, stock, rating, review_count, images, description,
  specs, is_featured, is_best_seller, is_new_arrival, is_trade_assurance,
  moq, wholesale_price, sku, warranty
) VALUES
  (
    'gh-phone-pro-max',
    'TitanEdge Pro Max 5G - 256GB Titanium Edition',
    'titanedge-pro-max-5g',
    'Mobile Phones',
    'mobiles',
    'TitanEdge',
    289999,
    329999,
    12,
    14,
    4.9,
    128,
    ARRAY['/src/assets/images/product_flagship_smartphone_1792425085549.jpg', 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?auto=format&fit=crop&w=800&q=80'],
    'Official PTA Approved flagship smartphone engineered with aerospace-grade Grade 5 titanium, 120Hz ProMotion LTPO OLED display, 50MP triple sensor matrix with 5x optical telephoto, and all-day silicon battery. Ships sealed with official 1-year brand warranty.',
    '{"Processor": "Snapdragon 8 Gen 3 (4nm)", "Display": "6.8\" LTPO AMOLED 120Hz HDR10+", "Storage": "256GB UFS 4.0", "RAM": "12GB LPDDR5X", "PTA Status": "Official Approved with Tax Paid Receipt", "Battery": "5,400 mAh with 80W Fast Charge", "Warranty": "1 Year Official Pakistan Warranty"}'::jsonb,
    TRUE, TRUE, FALSE, TRUE, 1, 279999, 'GH-MBL-8921', '12 Months Official Pakistan Warranty'
  ),
  (
    'gh-audio-anc-pro',
    'AcousticPure Studio Wireless ANC Headphones',
    'acousticpure-studio-anc',
    'Audio & Sound',
    'audio',
    'AcousticPure',
    38500,
    46000,
    16,
    22,
    4.8,
    94,
    ARRAY['/src/assets/images/product_wireless_headphones_1792425084428.jpg', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=800&q=80'],
    'Audiophile-tuned custom 40mm beryllium drivers delivering deep sub-bass and crystal-clear highs. Equipped with 4-microphone hybrid active noise cancellation, memory foam magnetic ear pads, and up to 55 hours of battery life with quick charge.',
    '{"Driver Size": "40mm Custom Beryllium Diaphragm", "ANC Tech": "Hybrid 4-Mic -42dB Ambient Filter", "Battery Life": "55 Hours (ANC Off) / 42 Hours (ANC On)", "Connectivity": "Bluetooth 5.4 + LDAC / AAC / aptX Lossless", "Weight": "248 grams", "Charging": "USB-C (10 min charge gives 5 hrs playback)"}'::jsonb,
    TRUE, TRUE, FALSE, TRUE, 1, 35000, 'GH-AUD-4410', '1 Year Replacement Warranty'
  ),
  (
    'gh-watch-ultra-titanium',
    'Chronos Ultra 2 GPS + Cellular Titanium Smartwatch',
    'chronos-ultra-2-smartwatch',
    'Smartwatches',
    'wearables',
    'Chronos',
    44999,
    52000,
    13,
    18,
    4.9,
    76,
    ARRAY['/src/assets/images/product_smartwatch_ultra_1792425084765.jpg', 'https://images.unsplash.com/photo-1579586337278-3befd40fd17a?auto=format&fit=crop&w=800&q=80'],
    'Rugged 49mm titanium chassis with sapphire crystal flat display delivering 3,000 nits peak brightness in direct Pakistani sunlight. Features dual-frequency precision GPS, ECG cardiac rhythm monitor, offline topographic maps, and 100m water resistance.',
    '{"Case Material": "Aerospace Grade Titanium 49mm", "Screen": "1.99\" Always-on Sapphire OLED (3,000 nits)", "Water Rating": "100m Water Resistant / EN13319 Dive Certified", "Battery": "Up to 72 hours in low power mode", "Sensors": "ECG, SpO2, Heart Rate, Skin Temperature, Compass", "Compatibility": "iOS 15+ and Android 10+"}'::jsonb,
    TRUE, TRUE, TRUE, TRUE, 1, 41500, 'GH-WCH-9011', '1 Year Official Replacement'
  ),
  (
    'gh-laptop-zenith-16',
    'ZenithBook Pro 16" M-Silicon Core Edition',
    'zenithbook-pro-16',
    'Computers & Laptops',
    'computers',
    'Zenith',
    495000,
    540000,
    8,
    6,
    5.0,
    42,
    ARRAY['/src/assets/images/hero_gadgethub_flagship_1792425083981.jpg', 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=800&q=80'],
    'The definitive creative workstation. Featuring 16.2-inch Liquid Retina XDR display with 1600 nits peak brightness, 36GB unified high-speed RAM, 1TB blazing NVMe SSD, and whisper-quiet cooling with 22-hour battery endurance.',
    '{"Chipset": "Zenith M3 Max 16-Core CPU / 40-Core GPU", "Memory": "36GB Unified Memory (300GB/s bandwidth)", "Storage": "1TB PCIe 4.0 NVMe Solid State Drive", "Display": "16.2\" Mini-LED ProMotion 120Hz (3456 x 2234)", "Ports": "3x Thunderbolt 4, HDMI 2.1, SDXC Slot, MagCharge", "Keyboard": "Magic Backlit with TouchID sensor"}'::jsonb,
    TRUE, FALSE, TRUE, TRUE, 1, 475000, 'GH-LPT-1601', '1 Year International + Local Pickup Warranty'
  ),
  (
    'gh-gan-charger-140w',
    'HyperPower 140W GaN 4-Port Fast Desktop Charger',
    'hyperpower-140w-gan-charger',
    'Accessories & Chargers',
    'accessories',
    'HyperPower',
    14500,
    17500,
    17,
    45,
    4.9,
    215,
    ARRAY['https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=800&q=80', 'https://images.unsplash.com/photo-1622445262464-84b1456045b6?auto=format&fit=crop&w=800&q=80'],
    'Next-gen Gallium Nitride (GaN III) semiconductor charger. Delivers PD 3.1 140W single-port output to charge a 16-inch laptop from 0% to 50% in just 28 minutes. Features 3x USB-C and 1x USB-A ports with dynamic power allocation.',
    '{"Total Output": "140W Max Output (PD 3.1 / QC 5.0 / PPS)", "Ports": "3x USB-C + 1x USB-A (Simultaneous charging)", "Safety": "Over-voltage, surge, and thermal throttling sensors", "Plug": "UK / Pakistan Standard 3-Pin Grounded Plug"}'::jsonb,
    FALSE, TRUE, FALSE, TRUE, 2, 12900, 'GH-ACC-140W', '6 Months Replacement Warranty'
  )
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  price = EXCLUDED.price,
  stock = EXCLUDED.stock,
  specs = EXCLUDED.specs;
