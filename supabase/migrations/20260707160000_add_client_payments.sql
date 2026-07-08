-- Add amount_paid to sales to record how much was paid at checkout
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS amount_paid NUMERIC DEFAULT 0;

-- Create client_payments table
CREATE TABLE IF NOT EXISTS public.client_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    sale_id UUID REFERENCES public.sales(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'cash',
    reference VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- RLS for client_payments
ALTER TABLE public.client_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "client_payments_select" ON public.client_payments FOR SELECT USING (
    store_id IN (
        SELECT store_id FROM public.store_members WHERE user_id = auth.uid()
    )
    OR store_id IN (
        SELECT id FROM public.stores WHERE created_by = auth.uid()
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

CREATE POLICY "client_payments_insert" ON public.client_payments FOR INSERT WITH CHECK (
    store_id IN (
        SELECT store_id FROM public.store_members WHERE user_id = auth.uid()
    )
    OR store_id IN (
        SELECT id FROM public.stores WHERE created_by = auth.uid()
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- Create a secure view for client debts
-- A client's total debt is the sum of all their sales (total_ttc) minus the sum of all their payments.
CREATE OR REPLACE VIEW public.client_debts_view AS
SELECT 
    c.id AS client_id,
    c.store_id,
    c.name,
    c.phone,
    COALESCE(SUM(s.total_ttc), 0) AS total_sales,
    (
        SELECT COALESCE(SUM(p.amount), 0)
        FROM public.client_payments p
        WHERE p.client_id = c.id
    ) AS total_paid,
    COALESCE(SUM(s.total_ttc), 0) - (
        SELECT COALESCE(SUM(p.amount), 0)
        FROM public.client_payments p
        WHERE p.client_id = c.id
    ) AS total_debt
FROM public.clients c
LEFT JOIN public.sales s ON s.client_id = c.id AND s.status = 'confirmed'
GROUP BY c.id, c.store_id, c.name, c.phone;
