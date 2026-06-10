-- Backend Permission Validation
-- Adds permission checks to RPC functions and data operations

-- 1. Helper Function to Check User Permissions
CREATE OR REPLACE FUNCTION check_user_permission(p_permission_key TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_is_admin BOOLEAN;
    v_has_role_permission BOOLEAN;
    v_has_legacy_permission BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    
    -- Check if user is null
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;
    
    -- Check if user is admin
    IF (auth.jwt()->>'role')::text = 'admin' THEN
        RETURN true;
    END IF;
    
    -- Check role-based permissions (new system)
    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.role_permissions rp ON ur.role_id = rp.role_id
        JOIN public.permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = v_user_id AND p.key = p_permission_key
    ) INTO v_has_role_permission;
    
    IF v_has_role_permission THEN
        RETURN true;
    END IF;
    
    -- Check legacy permission system as fallback
    CASE p_permission_key
        WHEN 'can_manage_products' THEN
            SELECT can_manage_products FROM public.user_permissions WHERE user_id = v_user_id INTO v_has_legacy_permission;
        WHEN 'can_manage_clients' THEN
            SELECT can_manage_clients FROM public.user_permissions WHERE user_id = v_user_id INTO v_has_legacy_permission;
        WHEN 'can_view_all_sales' THEN
            SELECT can_view_all_sales FROM public.user_permissions WHERE user_id = v_user_id INTO v_has_legacy_permission;
        WHEN 'can_cancel_sales' THEN
            SELECT can_cancel_sales FROM public.user_permissions WHERE user_id = v_user_id INTO v_has_legacy_permission;
        WHEN 'can_view_reports' THEN
            SELECT can_view_reports FROM public.user_permissions WHERE user_id = v_user_id INTO v_has_legacy_permission;
        WHEN 'can_manage_settings' THEN
            SELECT can_manage_settings FROM public.user_permissions WHERE user_id = v_user_id INTO v_has_legacy_permission;
        WHEN 'can_manage_users' THEN
            -- Legacy system doesn't have this, only role-based system
            RETURN false;
        WHEN 'can_manage_roles' THEN
            -- Legacy system doesn't have this, only role-based system
            RETURN false;
        ELSE
            RETURN false;
    END CASE;
    
    RETURN COALESCE(v_has_legacy_permission, false);
END;
$$;

-- 2. Update get_workers() to require can_manage_users permission
CREATE OR REPLACE FUNCTION get_workers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Check permission
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
            (SELECT COUNT(*) FROM sales s WHERE s.worker_id = u.id AND s.created_at >= date_trunc('month', now())) as sales_this_month,
            COALESCE(to_jsonb(p.*), '{}'::jsonb) as permissions
        FROM auth.users u
        LEFT JOIN public.user_permissions p ON p.user_id = u.id
        WHERE (u.raw_user_meta_data->>'role') IS NULL OR (u.raw_user_meta_data->>'role') != 'admin'
    ) worker_row;

    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- 3. Update update_worker_permissions() to require can_manage_users permission
CREATE OR REPLACE FUNCTION update_worker_permissions(p_user_id UUID, p_permissions JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check permission
    IF NOT check_user_permission('can_manage_users') THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_users required' USING ERRCODE = '403';
    END IF;
    
    -- Prevent users from giving themselves admin permissions
    IF p_user_id = auth.uid() AND (p_permissions->>'is_admin')::BOOLEAN = true THEN
        RAISE EXCEPTION 'Users cannot grant themselves admin privileges';
    END IF;
    
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

-- 4. Update role system RPC functions with permission validation

-- assign_role_to_user() requires can_manage_users or can_manage_roles
CREATE OR REPLACE FUNCTION assign_role_to_user(p_user_id UUID, p_role_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check permission
    IF NOT (check_user_permission('can_manage_users') OR check_user_permission('can_manage_roles')) THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_users or can_manage_roles required' USING ERRCODE = '403';
    END IF;
    
    INSERT INTO public.user_roles (user_id, role_id, assigned_by)
    VALUES (p_user_id, p_role_id, auth.uid())
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    RETURN true;
END;
$$;

-- remove_role_from_user() requires can_manage_users or can_manage_roles
CREATE OR REPLACE FUNCTION remove_role_from_user(p_user_id UUID, p_role_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check permission
    IF NOT (check_user_permission('can_manage_users') OR check_user_permission('can_manage_roles')) THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_users or can_manage_roles required' USING ERRCODE = '403';
    END IF;
    
    DELETE FROM public.user_roles
    WHERE user_id = p_user_id AND role_id = p_role_id;
    
    RETURN true;
END;
$$;

-- create_role() requires can_manage_roles
CREATE OR REPLACE FUNCTION create_role(p_name TEXT, p_description TEXT, p_permission_keys TEXT[])
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    role_id UUID;
BEGIN
    -- Check permission
    IF NOT check_user_permission('can_manage_roles') THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_roles required' USING ERRCODE = '403';
    END IF;
    
    -- Create the role
    INSERT INTO public.roles (name, description, created_by)
    VALUES (p_name, p_description, auth.uid())
    RETURNING id INTO role_id;
    
    -- Assign permissions to the role
    INSERT INTO public.role_permissions (role_id, permission_id)
    SELECT role_id, p.id
    FROM public.permissions p
    WHERE p.key = ANY(p_permission_keys)
    ON CONFLICT (role_id, permission_id) DO NOTHING;
    
    RETURN role_id;
END;
$$;

-- update_role() requires can_manage_roles
CREATE OR REPLACE FUNCTION update_role(p_role_id UUID, p_name TEXT, p_description TEXT, p_permission_keys TEXT[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check permission
    IF NOT check_user_permission('can_manage_roles') THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_roles required' USING ERRCODE = '403';
    END IF;
    
    -- Check if it's a system role (can't modify those)
    IF EXISTS (SELECT 1 FROM public.roles WHERE id = p_role_id AND is_system = true) THEN
        RAISE EXCEPTION 'Cannot modify system roles';
    END IF;
    
    -- Update the role
    UPDATE public.roles
    SET name = p_name, description = p_description, updated_at = timezone('utc'::text, now())
    WHERE id = p_role_id;
    
    -- Remove existing permissions
    DELETE FROM public.role_permissions WHERE role_id = p_role_id;
    
    -- Add new permissions
    INSERT INTO public.role_permissions (role_id, permission_id)
    SELECT p_role_id, p.id
    FROM public.permissions p
    WHERE p.key = ANY(p_permission_keys)
    ON CONFLICT (role_id, permission_id) DO NOTHING;
    
    RETURN true;
END;
$$;

-- 5. Create audit logging function (for security events)
CREATE OR REPLACE FUNCTION log_permission_check(p_permission_key TEXT, p_result BOOLEAN, p_details TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Log permission check results
    -- This helps track failed access attempts for security monitoring
    INSERT INTO public.permission_check_logs (
        user_id,
        permission_key,
        result,
        details,
        ip_address
    ) VALUES (
        auth.uid(),
        p_permission_key,
        p_result,
        p_details,
        COALESCE(current_setting('request.header.x-forwarded-for'), '0.0.0.0')
    );
END;
$$;

-- 6. Create permission check logs table (for audit trail)
CREATE TABLE IF NOT EXISTS public.permission_check_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    permission_key TEXT NOT NULL,
    result BOOLEAN NOT NULL,
    details TEXT,
    ip_address INET,
    checked_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_permission_checks ON public.permission_check_logs (user_id, checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_failed_checks ON public.permission_check_logs (result, checked_at DESC) WHERE result = false;

-- 7. Function to get permission check logs (for admin auditing)
CREATE OR REPLACE FUNCTION get_permission_check_logs(p_limit INT DEFAULT 100)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Only admins can view permission logs
    IF NOT (auth.jwt()->>'role')::text = 'admin' AND NOT check_user_permission('can_view_audit_logs') THEN
        RAISE EXCEPTION 'Insufficient permissions: can_view_audit_logs required' USING ERRCODE = '403';
    END IF;
    
    SELECT jsonb_agg(log_row) INTO result
    FROM (
        SELECT
            id,
            user_id,
            permission_key,
            result,
            details,
            checked_at
        FROM public.permission_check_logs
        WHERE result = false  -- Show failed permission checks
        ORDER BY checked_at DESC
        LIMIT p_limit
    ) log_row;
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- Grant EXECUTE permissions on new functions to authenticated users
GRANT EXECUTE ON FUNCTION check_user_permission(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_workers() TO authenticated;
GRANT EXECUTE ON FUNCTION update_worker_permissions(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION assign_role_to_user(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_role_from_user(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_role(TEXT, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION update_role(UUID, TEXT, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_permission_check_logs(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION log_permission_check(TEXT, BOOLEAN, TEXT) TO authenticated;

-- Allow authenticated users to insert permission check logs
GRANT INSERT ON TABLE public.permission_check_logs TO authenticated;
