-- Admin RPC & Tables

-- 1. Store Settings Table
CREATE TABLE IF NOT EXISTS public.store_settings (
    id INT PRIMARY KEY DEFAULT 1,
    name TEXT NOT NULL DEFAULT 'DELTAWARE STATIONARY',
    subtitle TEXT NOT NULL DEFAULT 'Vente en Gros et Détail',
    address TEXT NOT NULL DEFAULT 'Quartier Commercial, Alger',
    phone TEXT NOT NULL DEFAULT '0555 12 34 56',
    rc TEXT NOT NULL DEFAULT '16/00-1234567A20',
    nif TEXT NOT NULL DEFAULT '012345678912345',
    nis TEXT NOT NULL DEFAULT '123456789123456',
    ai TEXT NOT NULL DEFAULT '16012345678',
    default_margin_gros DECIMAL DEFAULT 10,
    default_margin_detail DECIMAL DEFAULT 20,
    enable_timbre BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Ensure only one row exists
INSERT INTO public.store_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- 2. User Permissions Table
CREATE TABLE IF NOT EXISTS public.user_permissions (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    can_manage_products BOOLEAN DEFAULT false,
    can_manage_clients BOOLEAN DEFAULT false,
    can_view_all_sales BOOLEAN DEFAULT false,
    can_cancel_sales BOOLEAN DEFAULT false,
    can_view_reports BOOLEAN DEFAULT false,
    can_manage_settings BOOLEAN DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read settings
CREATE POLICY "Allow read access to settings for everyone" ON public.store_settings FOR SELECT USING (true);
CREATE POLICY "Allow update access to settings for admins" ON public.store_settings FOR UPDATE USING (
    (auth.jwt()->>'role')::text = 'admin' OR 
    EXISTS (SELECT 1 FROM public.user_permissions WHERE user_id = auth.uid() AND can_manage_settings = true)
);

CREATE POLICY "Allow read permissions for everyone" ON public.user_permissions FOR SELECT USING (true);
CREATE POLICY "Allow update permissions for admins" ON public.user_permissions FOR UPDATE USING ((auth.jwt()->>'role')::text = 'admin');
CREATE POLICY "Allow insert permissions for admins" ON public.user_permissions FOR INSERT WITH CHECK ((auth.jwt()->>'role')::text = 'admin');

-- 3. Security Definer Function to List Workers
CREATE OR REPLACE FUNCTION get_workers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(worker_row) INTO result
    FROM (
        SELECT 
            u.id,
            u.email,
            COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown Worker') as full_name,
            u.last_sign_in_at,
            (SELECT COUNT(*) FROM sales s WHERE s.worker_id = u.id AND s.created_at >= date_trunc('month', now())) as sales_this_month,
            COALESCE(to_jsonb(p.*), '{}'::jsonb) as permissions
        FROM auth.users u
        LEFT JOIN public.user_permissions p ON p.user_id = u.id
        WHERE (u.raw_user_meta_data->>'role') IS NULL OR (u.raw_user_meta_data->>'role') != 'admin'
    ) worker_row;

    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- 4. Function to Update Permissions
CREATE OR REPLACE FUNCTION update_worker_permissions(p_user_id UUID, p_permissions JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_permissions (
        user_id, can_manage_products, can_manage_clients, can_view_all_sales, can_cancel_sales, can_view_reports, can_manage_settings
    ) VALUES (
        p_user_id,
        COALESCE((p_permissions->>'can_manage_products')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_manage_clients')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_view_all_sales')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_cancel_sales')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_view_reports')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_manage_settings')::BOOLEAN, false)
    )
    ON CONFLICT (user_id) DO UPDATE SET
        can_manage_products = EXCLUDED.can_manage_products,
        can_manage_clients = EXCLUDED.can_manage_clients,
        can_view_all_sales = EXCLUDED.can_view_all_sales,
        can_cancel_sales = EXCLUDED.can_cancel_sales,
        can_view_reports = EXCLUDED.can_view_reports,
        can_manage_settings = EXCLUDED.can_manage_settings,
        updated_at = timezone('utc'::text, now());
        
    RETURN true;
END;
$$;
