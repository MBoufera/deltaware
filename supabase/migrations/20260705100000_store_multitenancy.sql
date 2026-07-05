-- ============================================================
-- MIGRATION: Multi-Store Architecture
-- Adds stores table, store_members (many-to-many), scopes all
-- tenant data by store_id, and updates all RPC functions.
-- Existing data is safely migrated to a "Default Store".
-- ============================================================

BEGIN;

-- ============================================================
-- 1. STORES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.stores (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL DEFAULT 'Default Store',
    subtitle    TEXT NOT NULL DEFAULT 'Vente en Gros et Détail',
    address     TEXT NOT NULL DEFAULT '',
    wilaya      TEXT NOT NULL DEFAULT '',
    phone       TEXT NOT NULL DEFAULT '',
    nif         TEXT NOT NULL DEFAULT '',
    nis         TEXT NOT NULL DEFAULT '',
    rc          TEXT NOT NULL DEFAULT '',
    ai          TEXT NOT NULL DEFAULT '',
    logo_url    TEXT,
    enable_timbre BOOLEAN NOT NULL DEFAULT false,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. STORE_MEMBERS TABLE (many-to-many: user <-> store)
--    A single user can be a member of multiple stores.
--    store_role: 'admin' | 'worker'
-- ============================================================
CREATE TABLE IF NOT EXISTS public.store_members (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id    UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    store_role  TEXT NOT NULL DEFAULT 'worker',
    added_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(store_id, user_id)
);

-- ============================================================
-- 3. SEED DEFAULT STORE FROM EXISTING store_settings
-- ============================================================
DO $$
DECLARE
    v_has_settings BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM public.store_settings WHERE id = 1) INTO v_has_settings;

    IF v_has_settings THEN
        INSERT INTO public.stores (name, subtitle, address, phone, nif, nis, rc, ai)
        SELECT name, subtitle, address, phone, nif, nis, rc, ai
        FROM public.store_settings WHERE id = 1;
    ELSE
        INSERT INTO public.stores (name) VALUES ('Default Store');
    END IF;
END $$;

-- ============================================================
-- 4. ADD store_id COLUMNS TO ALL SCOPED TABLES
-- ============================================================
ALTER TABLE public.categories
    ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;

ALTER TABLE public.clients
    ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;

ALTER TABLE public.sales
    ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;

-- user_permissions needs composite PK (user_id, store_id)
ALTER TABLE public.user_permissions
    DROP CONSTRAINT IF EXISTS user_permissions_pkey;
ALTER TABLE public.user_permissions
    ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;

-- user_roles needs store_id for per-store role assignments
ALTER TABLE public.user_roles
    DROP CONSTRAINT IF EXISTS user_roles_pkey;
ALTER TABLE public.user_roles
    ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;

-- ============================================================
-- 5. MIGRATE ALL EXISTING DATA → DEFAULT STORE
-- ============================================================
DO $$
DECLARE
    v_default_store_id UUID;
BEGIN
    SELECT id INTO v_default_store_id FROM public.stores ORDER BY created_at ASC LIMIT 1;

    UPDATE public.categories       SET store_id = v_default_store_id WHERE store_id IS NULL;
    UPDATE public.products         SET store_id = v_default_store_id WHERE store_id IS NULL;
    UPDATE public.clients          SET store_id = v_default_store_id WHERE store_id IS NULL;
    UPDATE public.sales            SET store_id = v_default_store_id WHERE store_id IS NULL;
    UPDATE public.user_permissions SET store_id = v_default_store_id WHERE store_id IS NULL;
    UPDATE public.user_roles       SET store_id = v_default_store_id WHERE store_id IS NULL;

    -- Enroll all existing non-super-admin users in the default store
    INSERT INTO public.store_members (store_id, user_id, store_role)
    SELECT
        v_default_store_id,
        u.id,
        CASE WHEN (u.raw_user_meta_data->>'role') = 'admin' THEN 'admin' ELSE 'worker' END
    FROM auth.users u
    WHERE COALESCE((u.raw_user_meta_data->>'is_super_admin')::BOOLEAN, false) = false
    ON CONFLICT (store_id, user_id) DO NOTHING;
END $$;

-- ============================================================
-- 6. RE-ADD COMPOSITE PRIMARY KEYS
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'user_permissions_pkey' AND conrelid = 'public.user_permissions'::regclass
    ) THEN
        ALTER TABLE public.user_permissions ADD PRIMARY KEY (user_id, store_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'user_roles_pkey' AND conrelid = 'public.user_roles'::regclass
    ) THEN
        ALTER TABLE public.user_roles ADD PRIMARY KEY (user_id, role_id, store_id);
    END IF;
END $$;

-- ============================================================
-- 7. RLS FOR NEW TABLES
-- ============================================================
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stores_select" ON public.stores;
CREATE POLICY "stores_select" ON public.stores FOR SELECT USING (
    COALESCE((auth.jwt()->'user_metadata'->>'is_super_admin')::BOOLEAN, false) = true
    OR EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = stores.id AND sm.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "stores_insert" ON public.stores;
CREATE POLICY "stores_insert" ON public.stores FOR INSERT WITH CHECK (
    COALESCE((auth.jwt()->'user_metadata'->>'is_super_admin')::BOOLEAN, false) = true
);

DROP POLICY IF EXISTS "stores_update" ON public.stores;
CREATE POLICY "stores_update" ON public.stores FOR UPDATE USING (
    COALESCE((auth.jwt()->'user_metadata'->>'is_super_admin')::BOOLEAN, false) = true
    OR EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = stores.id AND sm.user_id = auth.uid() AND sm.store_role = 'admin'
    )
);

-- Helper security definer function to avoid RLS infinite recursion
CREATE OR REPLACE FUNCTION public.is_store_admin(p_store_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.store_members
        WHERE store_id = p_store_id
          AND user_id = p_user_id
          AND (store_role = 'admin' OR store_role = 'super_admin')
    );
END;
$$;

DROP POLICY IF EXISTS "store_members_select" ON public.store_members;
CREATE POLICY "store_members_select" ON public.store_members FOR SELECT USING (
    COALESCE((auth.jwt()->'user_metadata'->>'is_super_admin')::BOOLEAN, false) = true
    OR user_id = auth.uid()
    OR public.is_store_admin(store_id, auth.uid())
);

DROP POLICY IF EXISTS "store_members_manage" ON public.store_members;
CREATE POLICY "store_members_manage" ON public.store_members FOR ALL USING (
    COALESCE((auth.jwt()->'user_metadata'->>'is_super_admin')::BOOLEAN, false) = true
    OR public.is_store_admin(store_id, auth.uid())
);

-- ============================================================
-- 8. NEW RPC: get_stores()
-- Returns stores the current user can access.
-- Super admins see all stores. Others see only their enrolled stores.
-- ============================================================
CREATE OR REPLACE FUNCTION get_stores()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id       UUID := auth.uid();
    v_is_super_admin BOOLEAN;
    result          JSONB;
BEGIN
    SELECT COALESCE((raw_user_meta_data->>'is_super_admin')::BOOLEAN, false)
    INTO v_is_super_admin
    FROM auth.users WHERE id = v_user_id;

    IF v_is_super_admin THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id',           s.id,
                'name',         s.name,
                'subtitle',     s.subtitle,
                'address',      s.address,
                'wilaya',       s.wilaya,
                'phone',        s.phone,
                'nif',          s.nif,
                'nis',          s.nis,
                'rc',           s.rc,
                'ai',           s.ai,
                'logo_url',     s.logo_url,
                'enable_timbre', s.enable_timbre,
                'is_active',    s.is_active,
                'created_at',   s.created_at,
                'member_count', (SELECT COUNT(*) FROM store_members sm WHERE sm.store_id = s.id),
                'my_role',      'super_admin'
            ) ORDER BY s.created_at
        ), '[]'::jsonb) INTO result
        FROM public.stores s
        WHERE s.is_active = true;
    ELSE
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id',           s.id,
                'name',         s.name,
                'subtitle',     s.subtitle,
                'address',      s.address,
                'wilaya',       s.wilaya,
                'phone',        s.phone,
                'nif',          s.nif,
                'nis',          s.nis,
                'rc',           s.rc,
                'ai',           s.ai,
                'logo_url',     s.logo_url,
                'enable_timbre', s.enable_timbre,
                'is_active',    s.is_active,
                'created_at',   s.created_at,
                'member_count', (SELECT COUNT(*) FROM store_members sm2 WHERE sm2.store_id = s.id),
                'my_role',      sm.store_role
            ) ORDER BY s.created_at
        ), '[]'::jsonb) INTO result
        FROM public.stores s
        JOIN public.store_members sm ON sm.store_id = s.id AND sm.user_id = v_user_id
        WHERE s.is_active = true;
    END IF;

    RETURN result;
END;
$$;

-- ============================================================
-- 9. NEW RPC: create_store(...)
-- Super admin only. Seeds default categories for the new store.
-- ============================================================
CREATE OR REPLACE FUNCTION create_store(
    p_name        TEXT,
    p_subtitle    TEXT DEFAULT 'Vente en Gros et Détail',
    p_address     TEXT DEFAULT '',
    p_wilaya      TEXT DEFAULT '',
    p_phone       TEXT DEFAULT '',
    p_nif         TEXT DEFAULT '',
    p_nis         TEXT DEFAULT '',
    p_rc          TEXT DEFAULT '',
    p_ai          TEXT DEFAULT '',
    p_enable_timbre BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id       UUID := auth.uid();
    v_is_super_admin BOOLEAN;
    v_store_id      UUID;
BEGIN
    SELECT COALESCE((raw_user_meta_data->>'is_super_admin')::BOOLEAN, false)
    INTO v_is_super_admin
    FROM auth.users WHERE id = v_user_id;

    IF NOT v_is_super_admin THEN
        RAISE EXCEPTION 'Only super admins can create stores' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.stores (name, subtitle, address, wilaya, phone, nif, nis, rc, ai, enable_timbre, created_by)
    VALUES (p_name, p_subtitle, p_address, p_wilaya, p_phone, p_nif, p_nis, p_rc, p_ai, p_enable_timbre, v_user_id)
    RETURNING id INTO v_store_id;

    -- Seed default categories
    INSERT INTO public.categories (name_fr, tva_rate, store_id) VALUES
        ('Informatique',              19.00, v_store_id),
        ('Fournitures Scolaires',      9.00, v_store_id),
        ('Bureautique',               19.00, v_store_id),
        ('Trophées',                  19.00, v_store_id),
        ('Accessoires Informatique',  19.00, v_store_id);

    RETURN jsonb_build_object('success', true, 'store_id', v_store_id, 'name', p_name);
END;
$$;

-- ============================================================
-- 10. NEW RPC: update_store(...)
-- ============================================================
CREATE OR REPLACE FUNCTION update_store(
    p_store_id    UUID,
    p_name        TEXT,
    p_subtitle    TEXT DEFAULT '',
    p_address     TEXT DEFAULT '',
    p_wilaya      TEXT DEFAULT '',
    p_phone       TEXT DEFAULT '',
    p_nif         TEXT DEFAULT '',
    p_nis         TEXT DEFAULT '',
    p_rc          TEXT DEFAULT '',
    p_ai          TEXT DEFAULT '',
    p_enable_timbre BOOLEAN DEFAULT false
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id       UUID := auth.uid();
    v_is_super_admin BOOLEAN;
    v_is_store_admin BOOLEAN;
BEGIN
    SELECT COALESCE((raw_user_meta_data->>'is_super_admin')::BOOLEAN, false)
    INTO v_is_super_admin FROM auth.users WHERE id = v_user_id;

    SELECT EXISTS(
        SELECT 1 FROM public.store_members
        WHERE store_id = p_store_id AND user_id = v_user_id AND store_role = 'admin'
    ) INTO v_is_store_admin;

    IF NOT v_is_super_admin AND NOT v_is_store_admin THEN
        RAISE EXCEPTION 'Insufficient permissions to update store' USING ERRCODE = '42501';
    END IF;

    UPDATE public.stores SET
        name           = p_name,
        subtitle       = p_subtitle,
        address        = p_address,
        wilaya         = p_wilaya,
        phone          = p_phone,
        nif            = p_nif,
        nis            = p_nis,
        rc             = p_rc,
        ai             = p_ai,
        enable_timbre  = p_enable_timbre,
        updated_at     = now()
    WHERE id = p_store_id;

    RETURN true;
END;
$$;

-- ============================================================
-- 11. NEW RPC: add_store_member(p_store_id, p_user_id, p_role)
-- ============================================================
CREATE OR REPLACE FUNCTION add_store_member(
    p_store_id  UUID,
    p_user_id   UUID,
    p_role      TEXT DEFAULT 'worker'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id     UUID := auth.uid();
    v_is_super_admin BOOLEAN;
    v_is_store_admin BOOLEAN;
BEGIN
    SELECT COALESCE((raw_user_meta_data->>'is_super_admin')::BOOLEAN, false)
    INTO v_is_super_admin FROM auth.users WHERE id = v_caller_id;

    SELECT EXISTS(
        SELECT 1 FROM public.store_members
        WHERE store_id = p_store_id AND user_id = v_caller_id AND store_role = 'admin'
    ) INTO v_is_store_admin;

    IF NOT v_is_super_admin AND NOT v_is_store_admin THEN
        RAISE EXCEPTION 'Insufficient permissions to manage store members' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.store_members (store_id, user_id, store_role, added_by)
    VALUES (p_store_id, p_user_id, p_role, v_caller_id)
    ON CONFLICT (store_id, user_id) DO UPDATE SET store_role = EXCLUDED.store_role;

    RETURN true;
END;
$$;

-- ============================================================
-- 12. NEW RPC: remove_store_member(p_store_id, p_user_id)
-- ============================================================
CREATE OR REPLACE FUNCTION remove_store_member(p_store_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id     UUID := auth.uid();
    v_is_super_admin BOOLEAN;
    v_is_store_admin BOOLEAN;
BEGIN
    SELECT COALESCE((raw_user_meta_data->>'is_super_admin')::BOOLEAN, false)
    INTO v_is_super_admin FROM auth.users WHERE id = v_caller_id;

    SELECT EXISTS(
        SELECT 1 FROM public.store_members
        WHERE store_id = p_store_id AND user_id = v_caller_id AND store_role = 'admin'
    ) INTO v_is_store_admin;

    IF NOT v_is_super_admin AND NOT v_is_store_admin THEN
        RAISE EXCEPTION 'Insufficient permissions to remove store members' USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.store_members WHERE store_id = p_store_id AND user_id = p_user_id;
    RETURN true;
END;
$$;

-- ============================================================
-- 13. UPDATED RPC: get_workers(p_store_id)
-- ============================================================
CREATE OR REPLACE FUNCTION get_workers(p_store_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    IF p_store_id IS NULL THEN
        -- Legacy / super admin: all non-super-admin users
        SELECT COALESCE(jsonb_agg(w), '[]'::jsonb) INTO result
        FROM (
            SELECT
                u.id,
                u.email,
                COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown Worker') AS full_name,
                u.last_sign_in_at,
                (SELECT COUNT(*) FROM sales s WHERE s.worker_id = u.id
                    AND s.created_at >= date_trunc('month', now())) AS sales_this_month,
                COALESCE(
                    (
                        SELECT jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name, 'is_system', r.is_system))
                        FROM public.user_roles ur
                        JOIN public.roles r ON ur.role_id = r.id
                        WHERE ur.user_id = u.id
                    ),
                    '[]'::jsonb
                ) as roles,
                COALESCE(to_jsonb(p.*) - 'user_id' - 'store_id', '{}'::jsonb) AS permissions
            FROM auth.users u
            LEFT JOIN public.user_permissions p ON p.user_id = u.id
            WHERE COALESCE((u.raw_user_meta_data->>'is_super_admin')::BOOLEAN, false) = false
        ) w;
    ELSE
        SELECT COALESCE(jsonb_agg(w), '[]'::jsonb) INTO result
        FROM (
            SELECT
                u.id,
                u.email,
                COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown Worker') AS full_name,
                u.last_sign_in_at,
                sm.store_role,
                (SELECT COUNT(*) FROM sales s
                    WHERE s.worker_id = u.id AND s.store_id = p_store_id
                    AND s.created_at >= date_trunc('month', now())) AS sales_this_month,
                COALESCE(
                    (
                        SELECT jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name, 'is_system', r.is_system))
                        FROM public.user_roles ur
                        JOIN public.roles r ON ur.role_id = r.id
                        WHERE ur.user_id = u.id AND ur.store_id = p_store_id
                    ),
                    '[]'::jsonb
                ) as roles,
                COALESCE(to_jsonb(p.*) - 'user_id' - 'store_id', '{}'::jsonb) AS permissions
            FROM public.store_members sm
            JOIN auth.users u ON u.id = sm.user_id
            LEFT JOIN public.user_permissions p ON p.user_id = u.id AND p.store_id = p_store_id
            WHERE sm.store_id = p_store_id
              AND COALESCE((u.raw_user_meta_data->>'is_super_admin')::BOOLEAN, false) = false
        ) w;
    END IF;

    RETURN result;
END;
$$;

-- ============================================================
-- 14. UPDATED RPC: update_worker_permissions(p_user_id, p_permissions, p_store_id)
-- ============================================================
CREATE OR REPLACE FUNCTION update_worker_permissions(
    p_user_id       UUID,
    p_permissions   JSONB,
    p_store_id      UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_permissions (
        user_id, store_id,
        can_manage_products, can_manage_clients, can_view_all_sales,
        can_cancel_sales, can_view_reports, can_manage_settings
    ) VALUES (
        p_user_id,
        p_store_id,
        COALESCE((p_permissions->>'can_manage_products')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_manage_clients')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_view_all_sales')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_cancel_sales')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_view_reports')::BOOLEAN, false),
        COALESCE((p_permissions->>'can_manage_settings')::BOOLEAN, false)
    )
    ON CONFLICT (user_id, store_id) DO UPDATE SET
        can_manage_products = EXCLUDED.can_manage_products,
        can_manage_clients  = EXCLUDED.can_manage_clients,
        can_view_all_sales  = EXCLUDED.can_view_all_sales,
        can_cancel_sales    = EXCLUDED.can_cancel_sales,
        can_view_reports    = EXCLUDED.can_view_reports,
        can_manage_settings = EXCLUDED.can_manage_settings,
        updated_at          = now();

    RETURN true;
END;
$$;

-- ============================================================
-- 15. UPDATED RPC: get_user_permissions(p_user_id, p_store_id)
-- ============================================================
CREATE OR REPLACE FUNCTION get_user_permissions(
    p_user_id   UUID,
    p_store_id  UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Try role-based permissions scoped to store first
    SELECT COALESCE(jsonb_agg(DISTINCT p.key), '[]'::jsonb) INTO result
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON rp.role_id = ur.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = p_user_id
      AND (p_store_id IS NULL OR ur.store_id = p_store_id);

    -- If no RBAC permissions, fall back to legacy user_permissions
    IF result = '[]'::jsonb OR result IS NULL THEN
        SELECT COALESCE(
            jsonb_build_array(
                CASE WHEN can_manage_products THEN 'can_manage_products' END,
                CASE WHEN can_manage_clients  THEN 'can_manage_clients'  END,
                CASE WHEN can_view_all_sales  THEN 'can_view_all_sales'  END,
                CASE WHEN can_cancel_sales    THEN 'can_cancel_sales'    END,
                CASE WHEN can_view_reports    THEN 'can_view_reports'    END,
                CASE WHEN can_manage_settings THEN 'can_manage_settings' END
            ) - null,
            '[]'::jsonb
        ) INTO result
        FROM public.user_permissions
        WHERE user_id = p_user_id
          AND (p_store_id IS NULL OR store_id = p_store_id)
        LIMIT 1;
    END IF;

    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- ============================================================
-- 16. UPDATED RPC: get_analytics(start_date, end_date, p_store_id)
-- ============================================================
CREATE OR REPLACE FUNCTION get_analytics(
    start_date  TIMESTAMP,
    end_date    TIMESTAMP,
    p_store_id  UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_count       INT;
    v_total_revenue_ht  DECIMAL;
    v_total_tva         DECIMAL;
    v_total_timbre      DECIMAL;
    v_total_revenue_ttc DECIMAL;
    v_total_cost_price  DECIMAL;
    v_gross_profit      DECIMAL;
    v_timeline          JSONB;
    v_top_workers       JSONB;
    v_top_products      JSONB;
BEGIN
    SELECT
        COUNT(*),
        COALESCE(SUM(total_ht), 0),
        COALESCE(SUM(tva_amount), 0),
        COALESCE(SUM(timbre_fiscal), 0),
        COALESCE(SUM(total_ttc), 0)
    INTO v_sales_count, v_total_revenue_ht, v_total_tva, v_total_timbre, v_total_revenue_ttc
    FROM sales
    WHERE created_at >= start_date AND created_at <= end_date AND status = 'confirmed'
      AND (p_store_id IS NULL OR store_id = p_store_id);

    SELECT COALESCE(SUM(si.quantity * pp.prix_achat_super_gros), 0)
    INTO v_total_cost_price
    FROM sale_items si
    JOIN sales s ON s.id = si.sale_id
    JOIN product_pricing pp ON pp.product_id = si.product_id
    WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed'
      AND (p_store_id IS NULL OR s.store_id = p_store_id);

    v_gross_profit := v_total_revenue_ht - v_total_cost_price;

    SELECT jsonb_agg(tl) INTO v_timeline FROM (
        SELECT
            TO_CHAR(DATE(s.created_at), 'YYYY-MM-DD') AS date_label,
            COALESCE(SUM(s.total_ht), 0) AS revenue_ht,
            COALESCE(SUM(s.total_ht) - SUM(
                (SELECT COALESCE(SUM(si.quantity * pp.prix_achat_super_gros), 0)
                 FROM sale_items si
                 JOIN product_pricing pp ON pp.product_id = si.product_id
                 WHERE si.sale_id = s.id)
            ), 0) AS gross_profit
        FROM sales s
        WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed'
          AND (p_store_id IS NULL OR s.store_id = p_store_id)
        GROUP BY DATE(s.created_at)
        ORDER BY DATE(s.created_at)
    ) tl;

    SELECT jsonb_agg(wr) INTO v_top_workers FROM (
        SELECT
            u.id,
            COALESCE(u.raw_user_meta_data->>'full_name', u.email) AS name,
            COUNT(s.id) AS sales_count,
            COALESCE(SUM(s.total_ht), 0) AS revenue_ht
        FROM auth.users u
        JOIN sales s ON s.worker_id = u.id
        WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed'
          AND (p_store_id IS NULL OR s.store_id = p_store_id)
        GROUP BY u.id, u.email, u.raw_user_meta_data->>'full_name'
        ORDER BY revenue_ht DESC
        LIMIT 5
    ) wr;

    SELECT jsonb_agg(pr) INTO v_top_products FROM (
        SELECT
            p.id,
            p.name_fr,
            SUM(si.quantity)  AS qty_sold,
            SUM(si.total_ht)  AS revenue_ht
        FROM products p
        JOIN sale_items si ON si.product_id = p.id
        JOIN sales s ON s.id = si.sale_id
        WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed'
          AND (p_store_id IS NULL OR s.store_id = p_store_id)
        GROUP BY p.id, p.name_fr
        ORDER BY revenue_ht DESC
        LIMIT 5
    ) pr;

    RETURN jsonb_build_object(
        'kpi', jsonb_build_object(
            'sales_count',       v_sales_count,
            'total_revenue_ht',  v_total_revenue_ht,
            'total_cost_price',  v_total_cost_price,
            'gross_profit',      v_gross_profit,
            'margin_percent',    CASE WHEN v_total_revenue_ht > 0
                                      THEN (v_gross_profit / v_total_revenue_ht) * 100
                                      ELSE 0 END
        ),
        'timeline',     COALESCE(v_timeline,     '[]'::jsonb),
        'top_workers',  COALESCE(v_top_workers,  '[]'::jsonb),
        'top_products', COALESCE(v_top_products, '[]'::jsonb)
    );
END;
$$;

-- ============================================================
-- 17. UPDATED RPC: process_pos_sale — add store_id to sale
-- ============================================================
CREATE OR REPLACE FUNCTION process_pos_sale(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_id       UUID;
    v_sale_number   VARCHAR;
    v_year_prefix   VARCHAR;
    v_seq_val       INT;
    v_item          JSONB;
    v_product_id    UUID;
    v_qty           DECIMAL;
    v_sale_type     VARCHAR;
    v_store_id      UUID;
    v_current_stock DECIMAL;
    v_col_to_deduct VARCHAR;
BEGIN
    v_year_prefix := to_char(now(), 'YYYY');
    EXECUTE 'CREATE SEQUENCE IF NOT EXISTS sales_seq_' || v_year_prefix;
    v_seq_val     := nextval('sales_seq_' || v_year_prefix);
    v_sale_number := v_year_prefix || '-' || lpad(v_seq_val::text, 5, '0');
    v_sale_type   := payload->'sale'->>'sale_type';
    v_store_id    := (payload->'sale'->>'store_id')::UUID;

    INSERT INTO sales (
        sale_number, worker_id, client_id, sale_type, store_id,
        total_ht, tva_amount, timbre_fiscal, total_ttc, status, notes
    ) VALUES (
        v_sale_number,
        (payload->'sale'->>'worker_id')::UUID,
        NULLIF(payload->'sale'->>'client_id', '')::UUID,
        v_sale_type::sale_type_enum,
        v_store_id,
        (payload->'sale'->>'total_ht')::DECIMAL,
        (payload->'sale'->>'tva_amount')::DECIMAL,
        (payload->'sale'->>'timbre_fiscal')::DECIMAL,
        (payload->'sale'->>'total_ttc')::DECIMAL,
        'confirmed',
        payload->'sale'->>'notes'
    ) RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(payload->'items') LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty        := (v_item->>'quantity')::DECIMAL;

        v_col_to_deduct := CASE WHEN v_sale_type = 'detail' THEN 'qty_detail' ELSE 'qty_gros' END;

        EXECUTE format('SELECT %I FROM stock WHERE product_id = $1 FOR UPDATE', v_col_to_deduct)
        INTO v_current_stock USING v_product_id;

        IF v_current_stock IS NULL OR v_current_stock < v_qty THEN
            RAISE EXCEPTION 'Insufficient stock for product % (Available: %, Requested: %)',
                v_product_id, v_current_stock, v_qty;
        END IF;

        EXECUTE format('UPDATE stock SET %I = %I - $1 WHERE product_id = $2', v_col_to_deduct, v_col_to_deduct)
        USING v_qty, v_product_id;

        INSERT INTO sale_items (
            sale_id, product_id, quantity, unit_price_ht, tva_rate,
            unit_price_ttc, total_ht, total_ttc, discount_percent
        ) VALUES (
            v_sale_id,
            v_product_id,
            v_qty,
            (v_item->>'unit_price_ht')::DECIMAL,
            (v_item->>'tva_rate')::DECIMAL,
            (v_item->>'unit_price_ttc')::DECIMAL,
            (v_item->>'total_ht')::DECIMAL,
            (v_item->>'total_ttc')::DECIMAL,
            (v_item->>'discount_percent')::DECIMAL
        );
    END LOOP;

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'sale_number', v_sale_number);
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
END;

-- ============================================================
-- 17. UPDATED RPC: get_deep_analytics(start_date, end_date, p_store_id)
-- ============================================================
DROP FUNCTION IF EXISTS public.get_deep_analytics(timestamp with time zone, timestamp with time zone);

CREATE OR REPLACE FUNCTION public.get_deep_analytics(
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    p_store_id UUID DEFAULT NULL
) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  result JSON;
  kpis JSON;
  timeline JSON;
  top_workers JSON;
  top_products JSON;
  category_breakdown JSON;
BEGIN
  -- 1. KPIs
  SELECT json_build_object(
    'total_revenue_ht', COALESCE(SUM(total_ht), 0),
    'gross_profit', COALESCE(SUM(total_ht), 0) * 0.25, -- Approximated until COGS is strictly tracked
    'sales_count', COUNT(*),
    'margin_percent', 25.0
  ) INTO kpis
  FROM sales
  WHERE created_at >= start_date 
    AND created_at <= end_date
    AND (p_store_id IS NULL OR store_id = p_store_id);

  -- 2. Timeline (Daily revenue)
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO timeline
  FROM (
    SELECT 
      TO_CHAR(DATE(created_at), 'YYYY-MM-DD') as date_label,
      SUM(total_ht) as revenue_ht,
      SUM(total_ht) * 0.25 as gross_profit
    FROM sales
    WHERE created_at >= start_date 
      AND created_at <= end_date
      AND (p_store_id IS NULL OR store_id = p_store_id)
    GROUP BY DATE(created_at)
    ORDER BY DATE(created_at)
  ) t;

  -- 3. Top Workers
  SELECT COALESCE(json_agg(row_to_json(w)), '[]'::json) INTO top_workers
  FROM (
    SELECT 
      p.full_name as name,
      SUM(s.total_ht) as revenue_ht
    FROM sales s
    JOIN profiles p ON s.worker_id = p.id
    WHERE s.created_at >= start_date 
      AND created_at <= end_date
      AND (p_store_id IS NULL OR s.store_id = p_store_id)
    GROUP BY p.id, p.full_name
    ORDER BY revenue_ht DESC
    LIMIT 5
  ) w;

  -- 4. Top Products
  SELECT COALESCE(json_agg(row_to_json(tp)), '[]'::json) INTO top_products
  FROM (
    SELECT 
      p.name_fr,
      SUM(si.quantity) as qty_sold,
      SUM(si.total_ht) as revenue_ht
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE s.created_at >= start_date 
      AND s.created_at <= end_date
      AND (p_store_id IS NULL OR s.store_id = p_store_id)
    GROUP BY p.id, p.name_fr
    ORDER BY revenue_ht DESC
    LIMIT 10
  ) tp;

  -- 5. Category Breakdown
  SELECT COALESCE(json_agg(row_to_json(cb)), '[]'::json) INTO category_breakdown
  FROM (
    SELECT 
      c.name_fr as category_name,
      SUM(si.total_ht) as revenue_ht,
      SUM(si.quantity) as qty_sold
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    JOIN categories c ON p.category_id = c.id
    WHERE s.created_at >= start_date 
      AND s.created_at <= end_date
      AND (p_store_id IS NULL OR s.store_id = p_store_id)
    GROUP BY c.id, c.name_fr
    ORDER BY revenue_ht DESC
  ) cb;

  -- Combine into final result
  result := json_build_object(
    'kpi', kpis,
    'timeline', timeline,
    'top_workers', top_workers,
    'top_products', top_products,
    'category_breakdown', category_breakdown
  );

  RETURN result;
END;
$$;

COMMIT;

