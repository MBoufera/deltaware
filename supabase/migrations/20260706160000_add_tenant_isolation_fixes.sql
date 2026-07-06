-- Migration to fix store tenant isolation for super admins

-- 1. UPDATE STORES RLS POLICIES
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stores_select" ON public.stores;
CREATE POLICY "stores_select" ON public.stores FOR SELECT USING (
    created_by = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = stores.id AND sm.user_id = auth.uid()
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

DROP POLICY IF EXISTS "stores_insert" ON public.stores;
CREATE POLICY "stores_insert" ON public.stores FOR INSERT WITH CHECK (
    COALESCE((auth.jwt()->'user_metadata'->>'is_super_admin')::BOOLEAN, false) = true
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

DROP POLICY IF EXISTS "stores_update" ON public.stores;
CREATE POLICY "stores_update" ON public.stores FOR UPDATE USING (
    created_by = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = stores.id AND sm.user_id = auth.uid() AND sm.store_role = 'admin'
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

DROP POLICY IF EXISTS "stores_delete" ON public.stores;
CREATE POLICY "stores_delete" ON public.stores FOR DELETE USING (
    created_by = auth.uid()
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- 2. UPDATE STORE_MEMBERS RLS POLICIES
ALTER TABLE public.store_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_members_select" ON public.store_members;
CREATE POLICY "store_members_select" ON public.store_members FOR SELECT USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = store_members.store_id AND sm.user_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = store_members.store_id AND s.created_by = auth.uid()
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

DROP POLICY IF EXISTS "store_members_manage" ON public.store_members;
CREATE POLICY "store_members_manage" ON public.store_members FOR ALL USING (
    public.is_store_admin(store_id, auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = store_members.store_id AND s.created_by = auth.uid()
    )
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- 3. RECREATE get_stores()
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
        -- Super Admin / Store Owner: Only return stores they created or are enrolled in
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
                'my_role',      COALESCE(
                                    (SELECT sm.store_role FROM store_members sm WHERE sm.store_id = s.id AND sm.user_id = v_user_id),
                                    'super_admin'
                                )
            ) ORDER BY s.created_at
        ), '[]'::jsonb) INTO result
        FROM public.stores s
        WHERE s.is_active = true
          AND (s.created_by = v_user_id OR EXISTS (
              SELECT 1 FROM public.store_members sm 
              WHERE sm.store_id = s.id AND sm.user_id = v_user_id
          ));
    ELSE
        -- Standard worker/manager: Only return stores they are enrolled in
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

-- 4. RECREATE create_store(...)
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

    -- Enroll the creator as the admin of the store
    INSERT INTO public.store_members (store_id, user_id, store_role, added_by)
    VALUES (v_store_id, v_user_id, 'admin', v_user_id);

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
