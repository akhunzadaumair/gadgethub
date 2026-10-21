# Gadgethub - Premium Electronics & Online Shopping Platform

Gadgethub is a modern, high-performance e-commerce platform built for electronics and consumer tech retail in Pakistan. Inspired by Alibaba's high-density product discovery model, it features original branding, Cash on Delivery (COD) workflows, PTA-approval assurances, wholesale tier pricing, real-time shipment tracking, and a secure merchant admin management console.

---

## 🌟 Key Features

### 🛍️ Storefront & Discovery
- **Top Announcement Bar**: Displays Pakistan nationwide Cash on Delivery (COD) notice, free shipping threshold (orders over Rs. 5,000), and PTA compliance verification.
- **Instant Search & Mega Category Filter**: Alibaba-inspired search bar with category scoping, query highlighting, and clear actions.
- **8 Core Categories**: Mobile Phones, Audio & Sound, Smartwatches, Computers & Laptops, GaN Chargers & Accessories, Smart Home Appliances, Gaming, and Lifestyle Tech.
- **Rich Product Cards**: High-resolution photography, PKR (`Rs.`) tabular pricing, strike-through original prices, discount percentages, stock indicators, and quick Add to Cart & Wishlist toggles.
- **Product Detail Pages**: Multi-image galleries, full technical specifications tables, wholesale tier discounts (e.g. 3+ units discount), warranty details, and an interactive Pakistan city delivery time estimator (Lahore, Karachi, Islamabad, etc.).

### 🛒 Cart & Checkout
- **Slide-Out Cart Drawer**: Live item count, quantity steppers, voucher discount system (`GADGET10` for 10% off, `WELCOME500` for Rs. 500 off), free shipping calculation, and subtotal breakdown.
- **Pakistan-Optimized Checkout**: Form with full validation for 11-digit Pakistani mobile numbers (`03xx-xxxxxxx`), nationwide cities dropdown, street delivery address, and notes.
- **Payment Methods**:
  1. **Cash on Delivery (COD)** - 0% surcharge, inspect parcel upon delivery.
  2. **JazzCash / Easypaisa** - Direct mobile wallet transfer.
  3. **Bank Transfer** - Meezan Bank & HBL IBFT.
- **Instant Invoice & Order Confirmation**: Assigns realistic Pakistan courier tracking codes (TCS Express, Leopards Courier, PostEx) with a printable receipt invoice.

### 🚚 Courier Shipment Tracking
- Real-time 4-step progress stepper: `Placed` → `Processing` → `Shipped` → `Delivered`.
- Lookup by Order ID (e.g., `GH-PK-89211`) or Consignment Tracking Number.

### 🔒 Secure Merchant Admin Dashboard
- **Server-Side Authorization**: Protected by server-verified session tokens against the `ADMIN_PASSWORD` environment variable (no secrets exposed on the client).
- **Live Inventory Management**:
  - Add new products with title, category, brand, price (PKR), strike price, stock, SKU, specs, and wholesale tiers.
  - Device Image Uploader: Upload images directly from your computer via `/api/upload` or supply image URLs.
  - Inline stock editing and price updates.
  - Delete products with instant catalog synchronization.
- **Order Fulfillment Console**: View all customer shipping details, telephone numbers, order totals, and update delivery statuses (`Pending`, `Confirmed`, `Processing`, `Shipped`, `Delivered`, `Cancelled`).
- **Database Export & Reset**: One-click JSON backup export and catalog reset.

---

## 🏗️ Architecture & Tech Stack

- **Frontend**: React 19, TypeScript, Tailwind CSS v4, Lucide React, Motion.
- **Backend / API**: Express 4 running on Node.js via `tsx`.
- **Bundler / Dev Server**: Vite 8 with integrated middleware.
- **Database Engine**: Server-backed persistent JSON database (`data/gadgethub_db.json`) with full PostgreSQL / Supabase schema compatibility (`schema.sql`).

---

## 🚀 Getting Started

### Prerequisites
- Node.js 18+ or 20+ installed
- npm, pnpm, or bun

### 1. Installation
Clone or extract the repository, then install project dependencies:

```bash
npm install
```

### 2. Environment Configuration
Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Configuration variables:
```env
# Port for the server (defaults to 3000)
PORT=3000

# Store Owner Admin Password (used to unlock the Admin Panel)
ADMIN_PASSWORD="your-secure-admin-password"

# Optional: Supabase / PostgreSQL Credentials (if connecting to external database)
SUPABASE_URL="https://your-project.supabase.co"
SUPABASE_KEY="your-anon-or-service-role-key"
DATABASE_URL="postgresql://postgres:password@db.supabase.co:5432/postgres"
```

### 3. Run Locally (Development)
Start the Express server with Vite dev middleware:

```bash
npm run dev
```

The application will be running at [http://localhost:3000](http://localhost:3000).

### 4. Build for Production
To create an optimized production build:

```bash
npm run build
```

Then start the production server:

```bash
npm start
```

---

## ☁️ Deployment Guide (Why Netlify Fails & How to Deploy Correctly)

### ⚠️ Why Netlify Alone Shows 404 on Admin & Orders:
Gadgethub is a **Full-Stack Application** with both a React frontend AND an Express Node.js backend (`server.ts`).
1. **Netlify by default only hosts static frontend files (`dist/`)**. When you push to Netlify, it runs `vite build`, but it **does not run the Node server (`npm start`)**.
2. Because `server.ts` is not running on Netlify, every request to `/api/admin/login` or `/api/orders` returns **404 Not Found**. As a result:
   - Admin Panel cannot unlock.
   - Orders cannot reach the server, so stock is not validated and Resend emails cannot be sent.
3. In addition, Netlify requires you to explicitly add your environment variables in the Netlify Dashboard (**Site configuration > Environment variables**).

---

### 🚀 Recommended Full-Stack Deployment (Render.com - 100% Free):
To have both the storefront and the backend API running 24/7 seamlessly:

1. Create a free account at [render.com](https://render.com).
2. Click **New +** &rarr; **Web Service**.
3. Connect your Gadgethub GitHub repository.
4. Set the following settings:
   - **Name**: `gadgethub`
   - **Environment**: `Node`
   - **Build Command**: `npm run build`
   - **Start Command**: `npm start`
5. Click **Advanced** &rarr; **Add Environment Variable** and add:
   - `ADMIN_PASSWORD` = `Akhunzada@02389!`
   - `ORDER_NOTIFICATION_EMAIL` = `akhunzadaumair27@gmail.com`
   - `RESEND_API_KEY` = your Resend API key (`re_...`)
   - `SUPABASE_URL` = `https://hsxvytgcjandgnaenbgw.supabase.co`
   - `SUPABASE_KEY` = your Supabase key
6. Click **Create Web Service**.

Once deployed, Render will host both your frontend and Express backend on your custom URL (e.g., `https://gadgethub.onrender.com`), where Admin Login, Supabase Sync, and Email Notifications will work automatically!

---

## 🗄️ Supabase Cloud Database Setup Guide

Gadgethub is designed with dual-mode database support:
- **Default Mode**: Runs automatically on the local persistent JSON database engine (`data/gadgethub_db.json`). All products, stock levels, and customer orders persist across restarts without requiring any external accounts.
- **Supabase Cloud Mode**: Seamlessly switches to your Supabase PostgreSQL cloud instance when you supply your project credentials in `.env`.

### Step-by-Step Instructions:

#### 1. Create a Supabase Project
1. Go to [supabase.com](https://supabase.com) and sign in (or create a free account).
2. Click **New Project**, select an organization, enter `Gadgethub` as the project name, choose a database password, and select your nearest region.
3. Wait 1-2 minutes for the database to provision.

#### 2. Execute `schema.sql` in the Supabase SQL Editor
1. In your Supabase project dashboard, click on the **SQL Editor** icon in the left sidebar (looks like a terminal `>_` icon).
2. Click **+ New Query** at the top.
3. Open `schema.sql` in the root of this Gadgethub project, copy its entire contents, and paste it into the Supabase SQL editor query window.
4. Click the green **Run** button (or press `Ctrl+Enter` / `Cmd+Enter`).
5. You will see `Success. No rows returned` or a completion message confirming that:
   - `categories`, `products`, and `orders` tables are created with primary & foreign keys.
   - Auto-updating `updated_at` triggers and indexes are created.
   - Row Level Security (RLS) policies are active:
     - Categories and products are publicly readable.
     - Public customers can only insert their orders at checkout and cannot read other customers' private orders.
     - Only authorized administrators (via `service_role`) can update product catalogs, change prices, and update order delivery statuses.
   - Initial categories and flagship tech products are pre-seeded automatically.

#### 3. Retrieve Your Supabase Credentials
1. In your Supabase dashboard, click the gear icon (⚙️) at the bottom of the left sidebar to go to **Project Settings**.
2. Click on **API** under the Configuration section.
3. Copy the following two credentials:
   - **Project URL**: (e.g. `https://xyzcompany.supabase.co`) &rarr; assign to `SUPABASE_URL`
   - **Project API Keys**: Copy the **`service_role`** key (marked *Secret*) &rarr; assign to `SUPABASE_KEY`
     *(Note: The `service_role` key is required for backend server-side authorization so the server can manage inventory, stock levels, and order fulfillment while keeping customer orders protected by Row Level Security from the public).*

#### 4. Configure Your Environment Variables
In your project directory, open your `.env` file (or copy `.env.example` to `.env`) and update the values:

```env
# Required for Supabase Cloud Database:
SUPABASE_URL="https://your-actual-project-id.supabase.co"
SUPABASE_KEY="eyJhbGciOi..."

# Administrator Passkey for Store Owner Panel:
ADMIN_PASSWORD="your-secure-admin-password"

# Port (defaults to 3000):
PORT=3000
```

#### 5. Verify the Connection
Restart the development server:
```bash
npm run dev
```
Open the store at `http://localhost:3000`, open the **Admin** panel (using your configured `ADMIN_PASSWORD`), and click the **Database & Export** tab. The status indicator will switch to **Supabase Connected**!

---

## 🧪 Testing & Validation

Run TypeScript validation:
```bash
npm run lint
```

Build verification:
```bash
npm run build
```

---

## 📄 License

Apache-2.0
