-- Drop the unused/un-normalized supplier_invoices if it exists
DROP TABLE IF EXISTS public.supplier_invoices CASCADE;

-- 1. Create Purchase Invoices Table
CREATE TABLE IF NOT EXISTS public.purchase_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR NOT NULL,
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    total_ht NUMERIC NOT NULL DEFAULT 0,
    tva_amount NUMERIC NOT NULL DEFAULT 0,
    timbre_fiscal NUMERIC NOT NULL DEFAULT 0,
    total_ttc NUMERIC NOT NULL DEFAULT 0,
    status VARCHAR(50) DEFAULT 'confirmed',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    worker_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.purchase_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "purchase_invoices_select" ON public.purchase_invoices FOR SELECT USING (
    store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
    OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

CREATE POLICY "purchase_invoices_insert" ON public.purchase_invoices FOR INSERT WITH CHECK (
    store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
    OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- 2. Create Purchase Invoice Items Table
CREATE TABLE IF NOT EXISTS public.purchase_invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.purchase_invoices(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity NUMERIC NOT NULL,
    unit_price_ht NUMERIC NOT NULL,
    tva_rate NUMERIC DEFAULT 0,
    unit_price_ttc NUMERIC NOT NULL,
    total_ht NUMERIC NOT NULL,
    total_ttc NUMERIC NOT NULL,
    discount_percent NUMERIC DEFAULT 0
);

ALTER TABLE public.purchase_invoice_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "purchase_invoice_items_select" ON public.purchase_invoice_items FOR SELECT USING (
    invoice_id IN (
        SELECT id FROM public.purchase_invoices
        WHERE store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
           OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

CREATE POLICY "purchase_invoice_items_insert" ON public.purchase_invoice_items FOR INSERT WITH CHECK (
    invoice_id IN (
        SELECT id FROM public.purchase_invoices
        WHERE store_id IN (SELECT store_id FROM public.store_members WHERE user_id = auth.uid())
           OR store_id IN (SELECT id FROM public.stores WHERE created_by = auth.uid())
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- 3. Trigger to Update Stock when a Purchase Invoice Item is inserted
CREATE OR REPLACE FUNCTION update_stock_on_purchase()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.stock
    SET quantity = quantity + NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER purchase_item_insert_trigger
AFTER INSERT ON public.purchase_invoice_items
FOR EACH ROW
EXECUTE FUNCTION update_stock_on_purchase();

-- 4. Update supplier_debts_view
DROP VIEW IF EXISTS public.supplier_debts_view;
CREATE OR REPLACE VIEW public.supplier_debts_view AS
SELECT 
    s.id AS supplier_id,
    s.store_id,
    s.name,
    s.phone,
    (
        SELECT COALESCE(SUM(pi.total_ttc), 0)
        FROM public.purchase_invoices pi
        WHERE pi.supplier_id = s.id AND pi.status = 'confirmed'
    ) AS total_purchases,
    (
        SELECT COALESCE(SUM(p.amount), 0)
        FROM public.supplier_payments p
        WHERE p.supplier_id = s.id
    ) AS total_paid,
    (
        SELECT COALESCE(SUM(pi.total_ttc), 0)
        FROM public.purchase_invoices pi
        WHERE pi.supplier_id = s.id AND pi.status = 'confirmed'
    ) - (
        SELECT COALESCE(SUM(p.amount), 0)
        FROM public.supplier_payments p
        WHERE p.supplier_id = s.id
    ) AS total_debt
FROM public.suppliers s
GROUP BY s.id, s.store_id, s.name, s.phone;
