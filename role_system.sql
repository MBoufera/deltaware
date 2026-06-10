-- Role System Schema
-- This SQL should be appended to admin_rpc.sql or run separately

-- 5. Permissions Table (Master list of available permissions)
CREATE TABLE IF NOT EXISTS public.permissions (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'general',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 6. Roles Table
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN DEFAULT false, -- System roles cannot be deleted
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 7. Role Permissions Junction Table
CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id SERIAL REFERENCES public.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (role_id, permission_id)
);

-- 8. User Roles Junction Table (new - users can have multiple roles)
CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    PRIMARY KEY (user_id, role_id)
);

-- 9. Insert Default Permissions
INSERT INTO public.permissions (name, description, category) VALUES
    ('can_manage_products', 'Manage products and categories', 'products'),
    ('can_manage_clients', 'Manage client information', 'clients'),
    ('can_view_all_sales', 'View all sales records', 'sales'),
    ('can_cancel_sales', 'Cancel or return sales', 'sales'),
    ('can_view_reports', 'View analytics and reports', 'reports'),
    ('can_manage_settings', 'Manage store settings', 'settings'),
    ('can_manage_roles', 'Manage roles and permissions', 'admin'),
    ('can_manage_users', 'Manage user accounts', 'admin')
ON CONFLICT (name) DO NOTHING;

-- 10. Insert Default Roles
INSERT INTO public.roles (id, name, description, is_system) VALUES
    ('11111111-1111-1111-1111-111111111111'::uuid, 'Admin', 'Full system access', true),
    ('22222222-2222-2222-2222-222222222222'::uuid, 'Manager', 'Manage products, sales, and reports', true),
    ('33333333-3333-3333-3333-333333333333'::uuid, 'Cashier', 'Handle POS transactions only', true),
    ('44444444-4444-4444-4444-444444444444'::uuid, 'Warehouse', 'Manage stock and inventory', true)
ON CONFLICT DO NOTHING;

-- 11. Assign Permissions to Default Roles
-- Admin: All permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT '11111111-1111-1111-1111-111111111111'::uuid, id FROM public.permissions
ON CONFLICT DO NOTHING;

-- Manager: All except admin functions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT '22222222-2222-2222-2222-222222222222'::uuid, id FROM public.permissions
WHERE name != 'can_manage_roles' AND name != 'can_manage_users'
ON CONFLICT DO NOTHING;

-- Cashier: Only POS access (implicitly all authenticated users have this)
-- No specific permissions needed for POS

-- Warehouse: Product and stock management
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT '44444444-4444-4444-4444-444444444444'::uuid, id FROM public.permissions
WHERE name IN ('can_manage_products', 'can_view_all_sales')
ON CONFLICT DO NOTHING;

-- Enable RLS
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Policies for permissions table
CREATE POLICY "Allow read permissions for everyone" ON public.permissions FOR SELECT USING (true);
CREATE POLICY "Allow manage permissions for admins" ON public.permissions FOR ALL USING ((auth.jwt()->>'role')::text = 'admin');

-- Policies for roles table
CREATE POLICY "Allow read roles for everyone" ON public.roles FOR SELECT USING (true);
CREATE POLICY "Allow manage roles for admins" ON public.roles FOR ALL USING ((auth.jwt()->>'role')::text = 'admin');

-- Policies for role_permissions table
CREATE POLICY "Allow read role_permissions for everyone" ON public.role_permissions FOR SELECT USING (true);
CREATE POLICY "Allow manage role_permissions for admins" ON public.role_permissions FOR ALL USING ((auth.jwt()->>'role')::text = 'admin');

-- Policies for user_roles table
CREATE POLICY "Allow read user_roles for everyone" ON public.user_roles FOR SELECT USING (true);
CREATE POLICY "Allow manage user_roles for admins" ON public.user_roles FOR ALL USING ((auth.jwt()->>'role')::text = 'admin');

-- 12. Function to Get All Roles with Their Permissions
CREATE OR REPLACE FUNCTION get_roles_with_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(role_data) INTO result
    FROM (
        SELECT 
            r.id,
            r.name,
            r.description,
            r.is_system,
            r.created_at,
            r.updated_at,
            COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'name', p.name,
                    'description', p.description,
                    'category', p.category
                )
            ) FILTER (WHERE p.id IS NOT NULL), '[]'::jsonb) as permissions
        FROM public.roles r
        LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
        LEFT JOIN public.permissions p ON p.id = rp.permission_id
        GROUP BY r.id, r.name, r.description, r.is_system, r.created_at, r.updated_at
    ) role_data;
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- 13. Function to Get All Permissions
CREATE OR REPLACE FUNCTION get_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', id,
                'name', name,
                'description', description,
                'category', category
            ) ORDER BY category, name
        )
        FROM public.permissions
    );
END;
$$;

-- 14. Function to Create a Role
CREATE OR REPLACE FUNCTION create_role(p_name TEXT, p_description TEXT, p_permission_ids INT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role_id UUID;
    v_result JSONB;
BEGIN
    -- Insert the role
    INSERT INTO public.roles (name, description, created_by)
    VALUES (p_name, p_description, auth.uid())
    RETURNING id INTO v_role_id;
    
    -- Insert role permissions
    INSERT INTO public.role_permissions (role_id, permission_id)
    SELECT v_role_id, UNNEST(p_permission_ids);
    
    -- Return the created role with permissions
    SELECT jsonb_build_object(
        'id', r.id,
        'name', r.name,
        'description', r.description,
        'is_system', r.is_system,
        'permissions', COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'name', p.name
            )
        ) FILTER (WHERE p.id IS NOT NULL), '[]'::jsonb)
    ) INTO v_result
    FROM public.roles r
    LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
    LEFT JOIN public.permissions p ON p.id = rp.permission_id
    WHERE r.id = v_role_id
    GROUP BY r.id, r.name, r.description, r.is_system;
    
    RETURN v_result;
END;
$$;

-- 15. Function to Update a Role
CREATE OR REPLACE FUNCTION update_role(p_role_id UUID, p_name TEXT, p_description TEXT, p_permission_ids INT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_system BOOLEAN;
    v_result JSONB;
BEGIN
    -- Check if role is system role (cannot modify system roles)
    SELECT is_system INTO v_is_system FROM public.roles WHERE id = p_role_id;
    
    IF v_is_system THEN
        RAISE EXCEPTION 'Cannot modify system roles';
    END IF;
    
    -- Update the role
    UPDATE public.roles
    SET name = p_name, description = p_description, updated_at = timezone('utc'::text, now())
    WHERE id = p_role_id;
    
    -- Delete old permissions and insert new ones
    DELETE FROM public.role_permissions WHERE role_id = p_role_id;
    INSERT INTO public.role_permissions (role_id, permission_id)
    SELECT p_role_id, UNNEST(p_permission_ids);
    
    -- Return the updated role
    SELECT jsonb_build_object(
        'id', r.id,
        'name', r.name,
        'description', r.description,
        'is_system', r.is_system,
        'permissions', COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'name', p.name
            )
        ) FILTER (WHERE p.id IS NOT NULL), '[]'::jsonb)
    ) INTO v_result
    FROM public.roles r
    LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
    LEFT JOIN public.permissions p ON p.id = rp.permission_id
    WHERE r.id = p_role_id
    GROUP BY r.id, r.name, r.description, r.is_system;
    
    RETURN v_result;
END;
$$;

-- 16. Function to Delete a Role
CREATE OR REPLACE FUNCTION delete_role(p_role_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_system BOOLEAN;
BEGIN
    -- Check if role is system role
    SELECT is_system INTO v_is_system FROM public.roles WHERE id = p_role_id;
    
    IF v_is_system THEN
        RAISE EXCEPTION 'Cannot delete system roles';
    END IF;
    
    -- Delete the role (cascade will remove permissions and user assignments)
    DELETE FROM public.roles WHERE id = p_role_id;
    
    RETURN true;
END;
$$;

-- 17. Function to Assign Role to User
CREATE OR REPLACE FUNCTION assign_role_to_user(p_user_id UUID, p_role_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_roles (user_id, role_id, assigned_by)
    VALUES (p_user_id, p_role_id, auth.uid())
    ON CONFLICT DO NOTHING;
    
    RETURN true;
END;
$$;

-- 18. Function to Remove Role from User
CREATE OR REPLACE FUNCTION remove_role_from_user(p_user_id UUID, p_role_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.user_roles WHERE user_id = p_user_id AND role_id = p_role_id;
    RETURN true;
END;
$$;

-- 19. Function to Get User with Roles and Permissions
CREATE OR REPLACE FUNCTION get_user_with_roles(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', u.id,
        'email', u.email,
        'full_name', COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown'),
        'roles', COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', r.id,
                'name', r.name,
                'description', r.description
            )
        ) FILTER (WHERE r.id IS NOT NULL), '[]'::jsonb),
        'permissions', (
            SELECT jsonb_agg(DISTINCT p.name)
            FROM public.user_roles ur
            JOIN public.roles r ON r.id = ur.role_id
            LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
            LEFT JOIN public.permissions p ON p.id = rp.permission_id
            WHERE ur.user_id = p_user_id AND p.name IS NOT NULL
        )
    ) INTO result
    FROM auth.users u
    LEFT JOIN public.user_roles ur ON ur.user_id = u.id
    LEFT JOIN public.roles r ON r.id = ur.role_id
    WHERE u.id = p_user_id
    GROUP BY u.id, u.email, u.raw_user_meta_data;
    
    RETURN COALESCE(result, '{}'::jsonb);
END;
$$;

-- 20. Function to Get Workers with Roles
CREATE OR REPLACE FUNCTION get_workers_with_roles()
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
            COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', r.id,
                    'name', r.name
                )
            ) FILTER (WHERE r.id IS NOT NULL), '[]'::jsonb) as roles
        FROM auth.users u
        LEFT JOIN public.user_roles ur ON ur.user_id = u.id
        LEFT JOIN public.roles r ON r.id = ur.role_id
        WHERE (u.raw_user_meta_data->>'role') IS NULL OR (u.raw_user_meta_data->>'role') != 'admin'
        GROUP BY u.id, u.email, u.raw_user_meta_data
    ) worker_row;

    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;
