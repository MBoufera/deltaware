-- Create supplier_type ENUM if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'supplier_type') THEN
        CREATE TYPE public.supplier_type AS ENUM ('particulier', 'entreprise', 'gouvernement');
    END IF;
END $$;

-- 1. Create Suppliers Table
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    type public.supplier_type DEFAULT 'entreprise'::public.supplier_type,
    address TEXT,
    wilaya VARCHAR,
    nif VARCHAR,
    nis VARCHAR,
    rc VARCHAR,
    ai VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "suppliers_select" ON public.suppliers FOR SELECT USING (
    store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
    OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

CREATE POLICY "suppliers_insert" ON public.suppliers FOR INSERT WITH CHECK (
    store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
    OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

CREATE POLICY "suppliers_update" ON public.suppliers FOR UPDATE USING (
    store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
    OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- 2. Create Supplier Payments Table
CREATE TABLE IF NOT EXISTS public.supplier_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    -- We can link this to purchase_orders later when they exist
    -- purchase_id UUID REFERENCES public.purchases(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'cash',
    reference VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.supplier_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplier_payments_select" ON public.supplier_payments FOR SELECT USING (
    store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
    OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

CREATE POLICY "supplier_payments_insert" ON public.supplier_payments FOR INSERT WITH CHECK (
    store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
    OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- 3. Create Supplier Debts View
-- Note: total_purchases is 0 for now until the Purchases feature is implemented.
-- So debt will temporarily be negative (credit) if you just add payments.
CREATE OR REPLACE VIEW public.supplier_debts_view AS
SELECT 
    s.id AS supplier_id,
    s.store_id,
    s.name,
    s.phone,
    0 AS total_purchases, -- Placeholder until Purchases are implemented
    (
        SELECT COALESCE(SUM(p.amount), 0)
        FROM public.supplier_payments p
        WHERE p.supplier_id = s.id
    ) AS total_paid,
    0 - (
        SELECT COALESCE(SUM(p.amount), 0)
        FROM public.supplier_payments p
        WHERE p.supplier_id = s.id
    ) AS total_debt
FROM public.suppliers s
GROUP BY s.id, s.store_id, s.name, s.phone;
