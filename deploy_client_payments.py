import psycopg2

def main():
    conn = psycopg2.connect(
        host="aws-0-eu-west-1.pooler.supabase.com",
        database="postgres",
        user="postgres.dggulctustnlfyadcanx",
        password="DeltawareStationary2026",
        port="5432"
    )
    cur = conn.cursor()
    
    sql_commands = """
    ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS amount_paid NUMERIC DEFAULT 0;

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

    ALTER TABLE public.client_payments ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "client_payments_select" ON public.client_payments;
    CREATE POLICY "client_payments_select" ON public.client_payments FOR SELECT USING (
        store_id IN (
            SELECT store_id FROM public.store_members WHERE user_id = auth.uid()
        )
        OR store_id IN (
            SELECT id FROM public.stores WHERE created_by = auth.uid()
        )
        OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
    );

    DROP POLICY IF EXISTS "client_payments_insert" ON public.client_payments;
    CREATE POLICY "client_payments_insert" ON public.client_payments FOR INSERT WITH CHECK (
        store_id IN (
            SELECT store_id FROM public.store_members WHERE user_id = auth.uid()
        )
        OR store_id IN (
            SELECT id FROM public.stores WHERE created_by = auth.uid()
        )
        OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
    );

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
    """
    
    try:
        print("Deploying client payments migration to Supabase...")
        cur.execute(sql_commands)
        conn.commit()
        print("Deployment successful!")
    except Exception as e:
        print(f"Error: {e}")
        conn.rollback()
        
    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
