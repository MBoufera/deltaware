-- RBAC Full Migration
-- Removes the legacy user_permissions fallback from check_user_permission()
-- and updates get_workers() to include assigned role names.

-- 1. Rewrite check_user_permission() — RBAC only, no legacy fallback
CREATE OR REPLACE FUNCTION check_user_permission(p_permission_key TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- Admins (JWT role = 'admin') always have all permissions
    IF (auth.jwt()->>'role')::text = 'admin' THEN
        RETURN true;
    END IF;

    -- RBAC only: check user_roles -> role_permissions -> permissions
    RETURN EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.role_permissions rp ON ur.role_id = rp.role_id
        JOIN public.permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = v_user_id AND p.key = p_permission_key
    );
END;
$$;

-- 2. Update get_workers() to include assigned role names for display
CREATE OR REPLACE FUNCTION get_workers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    IF NOT check_user_permission('can_manage_users') THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_users required' USING ERRCODE = '403';
    END IF;

    SELECT jsonb_agg(worker_row) INTO result
    FROM (
        SELECT
            u.id,
            u.email,
            COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown Worker') as full_name,
            u.last_sign_in_at,
            (
                SELECT COUNT(*)
                FROM sales s
                WHERE s.worker_id = u.id AND s.created_at >= date_trunc('month', now())
            ) as sales_this_month,
            -- Include assigned role names as a JSON array
            COALESCE(
                (
                    SELECT jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name, 'is_system', r.is_system))
                    FROM public.user_roles ur
                    JOIN public.roles r ON ur.role_id = r.id
                    WHERE ur.user_id = u.id
                ),
                '[]'::jsonb
            ) as roles
        FROM auth.users u
        WHERE (u.raw_user_meta_data->>'role') IS NULL
           OR (u.raw_user_meta_data->>'role') != 'admin'
    ) worker_row;

    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;
