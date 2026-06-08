-- deltaware/schema_v2.sql
-- Phase 1 Sprint 2 Strict Schema Migration

-- Drop existing simplified tables to recreate them strictly according to schema.json
DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS stock CASCADE;
DROP TABLE IF EXISTS product_pricing CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;

-- ENUMS
DO $$ BEGIN
    CREATE TYPE client_type AS ENUM ('particulier', 'entreprise', 'gouvernement');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE sale_type_enum AS ENUM ('detail', 'gros', 'bon_livraison', 'bon_commande', 'gouvernement');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE sale_status AS ENUM ('pending', 'confirmed', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE doc_type AS ENUM ('facture', 'bon_livraison', 'bon_commande', 'recu');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- P1-S2-T2: CATEGORIES
CREATE TABLE categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name_fr VARCHAR NOT NULL,
    name_ar VARCHAR,
    tva_rate DECIMAL(5,2) DEFAULT 19.00,
    icon VARCHAR,
    description TEXT,
    is_active BOOLEAN DEFAULT true
);

-- P1-S2-T3: PRODUCTS
CREATE TABLE products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ref_code VARCHAR UNIQUE,
    name_fr VARCHAR NOT NULL,
    name_ar VARCHAR,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    unit VARCHAR DEFAULT 'pièce',
    image_url TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- P1-S2-T4: PRODUCT PRICING
CREATE TABLE product_pricing (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE UNIQUE,
    prix_achat_super_gros DECIMAL(12,2) NOT NULL,
    marge_gros_percent DECIMAL(5,2) DEFAULT 10.00,
    prix_vente_gros_ht DECIMAL(12,2) GENERATED ALWAYS AS (prix_achat_super_gros * (1 + marge_gros_percent/100)) STORED,
    marge_detail_percent DECIMAL(5,2) DEFAULT 20.00,
    -- Compute retail off gros price
    prix_vente_detail_ht DECIMAL(12,2) GENERATED ALWAYS AS ((prix_achat_super_gros * (1 + marge_gros_percent/100)) * (1 + marge_detail_percent/100)) STORED,
    tva_rate DECIMAL(5,2) DEFAULT 19.00,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- P1-S2-T5: STOCK
CREATE TABLE stock (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE UNIQUE,
    qty_super_gros DECIMAL(12,3) DEFAULT 0,
    qty_gros DECIMAL(12,3) DEFAULT 0,
    qty_detail DECIMAL(12,3) DEFAULT 0,
    alert_threshold DECIMAL(12,3) DEFAULT 5,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- P1-S2-T6: CLIENTS
CREATE TABLE clients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR NOT NULL,
    type client_type DEFAULT 'particulier',
    address TEXT,
    wilaya VARCHAR,
    nif VARCHAR,
    nis VARCHAR,
    rc VARCHAR,
    ai VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- P1-S2-T7: SALES
CREATE TABLE sales (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sale_number VARCHAR UNIQUE,
    worker_id UUID, -- References users(id), skipping strict FK if users table is managed by Supabase Auth
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    sale_type sale_type_enum DEFAULT 'detail',
    total_ht DECIMAL(14,2),
    tva_amount DECIMAL(14,2),
    timbre_fiscal DECIMAL(14,2) DEFAULT 0,
    total_ttc DECIMAL(14,2),
    status sale_status DEFAULT 'confirmed',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- P1-S2-T8: SALE ITEMS
CREATE TABLE sale_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE RESTRICT,
    quantity DECIMAL(12,3) NOT NULL,
    unit_price_ht DECIMAL(12,2) NOT NULL,
    tva_rate DECIMAL(5,2),
    unit_price_ttc DECIMAL(12,2),
    total_ht DECIMAL(14,2),
    total_ttc DECIMAL(14,2),
    discount_percent DECIMAL(5,2) DEFAULT 0
);

-- P1-S2-T9: DOCUMENTS
CREATE TABLE documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    document_type doc_type,
    document_number VARCHAR UNIQUE,
    file_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- P1-S2-T10: APP SETTINGS
CREATE TABLE app_settings (
    key VARCHAR PRIMARY KEY,
    value JSONB,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed Settings
INSERT INTO app_settings (key, value) VALUES 
('store_name', '"Deltaware"'),
('address', '""'),
('wilaya', '""'),
('phone', '""'),
('nif', '""'),
('nis', '""'),
('rc', '""'),
('ai', '""'),
('logo_url', '""'),
('default_tva_rate', '19.00'),
('default_margin_gros', '10.00'),
('default_margin_detail', '20.00'),
('timbre_fiscal_enabled', 'false'),
('timbre_fiscal_rate', '1.00'),
('primary_language', '"fr"')
ON CONFLICT (key) DO NOTHING;

-- Seed Categories (P1-S2-T12)
INSERT INTO categories (name_fr, tva_rate) VALUES 
('Informatique', 19.00),
('Fournitures Scolaires', 9.00),
('Bureautique', 19.00),
('Trophées', 19.00),
('Accessoires Informatique', 19.00);

-- Setup RLS (Basic public access for dev; can be tightened later per T11)
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all for anon/auth" ON categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON product_pricing FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON stock FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON clients FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON sales FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON sale_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON documents FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon/auth" ON app_settings FOR ALL USING (true) WITH CHECK (true);
