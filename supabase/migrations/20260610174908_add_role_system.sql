-- Role System Schema
-- This adds comprehensive role-based access control to the application

-- 0. Drop existing tables to ensure clean schema
DROP TABLE IF EXISTS public.permissions CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;
DROP TABLE IF EXISTS public.role_permissions CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;

-- 1. Create Roles Table
CREATE TABLE public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN DEFAULT false, -- System roles cannot be deleted
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Create Permissions Table (centralized permission registry)
CREATE TABLE public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'general', -- e.g., 'products', 'sales', 'reports', 'admin'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. Create Role-Permission Junction Table
CREATE TABLE public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(role_id, permission_id)
);

-- 4. Create User-Role Junction Table
CREATE TABLE public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, role_id)
);

-- 5. Insert Default Permissions
INSERT INTO public.permissions (key, name, description, category) VALUES
    ('can_manage_products', 'Manage Products', 'Create, update, and delete products', 'products'),
    ('can_manage_clients', 'Manage Clients', 'Manage client information and records', 'clients'),
    ('can_view_all_sales', 'View All Sales', 'View sales records from all users', 'sales'),
    ('can_cancel_sales', 'Cancel Sales', 'Cancel and reverse sales transactions', 'sales'),
    ('can_view_reports', 'View Reports', 'Access analytics and reporting dashboards', 'reports'),
    ('can_manage_settings', 'Manage Settings', 'Modify application and store settings', 'admin'),
    ('can_manage_users', 'Manage Users', 'Create, update, and manage user accounts', 'admin'),
    ('can_manage_roles', 'Manage Roles', 'Create, update, delete, and assign roles', 'admin'),
    ('can_manage_permissions', 'Manage Permissions', 'Configure permission system', 'admin'),
    ('can_view_audit_logs', 'View Audit Logs', 'Access system audit and activity logs', 'admin')
ON CONFLICT (key) DO NOTHING;

-- 6. Insert Default System Roles
INSERT INTO public.roles (name, description, is_system) VALUES
    ('Admin', 'Full system access', true),
    ('Manager', 'Management and reporting access', true),
    ('Staff', 'Basic operational access', true),
    ('Viewer', 'Read-only access to reports', true)
ON CONFLICT (name) DO NOTHING;

-- 7. Assign All Permissions to Admin Role
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id 
FROM public.roles r, public.permissions p 
WHERE r.name = 'Admin'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 8. Assign Manager Permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r, public.permissions p
WHERE r.name = 'Manager' 
AND p.key IN ('can_manage_products', 'can_view_all_sales', 'can_view_reports', 'can_manage_clients')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 9. Assign Staff Permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r, public.permissions p
WHERE r.name = 'Staff' 
AND p.key IN ('can_manage_products', 'can_view_reports')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 10. Assign Viewer Permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r, public.permissions p
WHERE r.name = 'Viewer' 
AND p.key IN ('can_view_reports')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 11. Enable RLS
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- 12. RLS Policies

-- Roles - everyone can read, only admins can modify
CREATE POLICY "Allow read roles for everyone" ON public.roles FOR SELECT USING (true);
CREATE POLICY "Allow insert roles for admins" ON public.roles FOR INSERT WITH CHECK (
    (auth.jwt()->>'role')::text = 'admin' OR
    EXISTS (SELECT 1 FROM public.user_roles ur 
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid() AND p.key = 'can_manage_roles')
);
CREATE POLICY "Allow update roles for admins" ON public.roles FOR UPDATE USING (
    ((auth.jwt()->>'role')::text = 'admin' AND is_system = false) OR
    (EXISTS (SELECT 1 FROM public.user_roles ur 
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid() AND p.key = 'can_manage_roles' AND is_system = false))
);
CREATE POLICY "Allow delete roles for admins" ON public.roles FOR DELETE USING (
    ((auth.jwt()->>'role')::text = 'admin' AND is_system = false) OR
    (EXISTS (SELECT 1 FROM public.user_roles ur 
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid() AND p.key = 'can_manage_roles' AND is_system = false))
);

-- Permissions - read-only for all
CREATE POLICY "Allow read permissions for everyone" ON public.permissions FOR SELECT USING (true);

-- Role Permissions - read-only for all
CREATE POLICY "Allow read role_permissions for everyone" ON public.role_permissions FOR SELECT USING (true);
CREATE POLICY "Allow insert role_permissions for admins" ON public.role_permissions FOR INSERT WITH CHECK (
    (auth.jwt()->>'role')::text = 'admin' OR
    EXISTS (SELECT 1 FROM public.user_roles ur 
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid() AND p.key = 'can_manage_roles')
);
CREATE POLICY "Allow delete role_permissions for admins" ON public.role_permissions FOR DELETE USING (
    (auth.jwt()->>'role')::text = 'admin' OR
    EXISTS (SELECT 1 FROM public.user_roles ur 
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid() AND p.key = 'can_manage_roles')
);

-- User Roles - users can read their own, admins can modify
CREATE POLICY "Allow read user_roles for everyone" ON public.user_roles FOR SELECT USING (true);
CREATE POLICY "Allow insert user_roles for admins" ON public.user_roles FOR INSERT WITH CHECK (
    (auth.jwt()->>'role')::text = 'admin' OR
    EXISTS (SELECT 1 FROM public.user_roles ur 
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid() AND p.key = 'can_manage_users')
);
CREATE POLICY "Allow delete user_roles for admins" ON public.user_roles FOR DELETE USING (
    (auth.jwt()->>'role')::text = 'admin' OR
    EXISTS (SELECT 1 FROM public.user_roles ur 
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid() AND p.key = 'can_manage_users')
);

-- 13. Function to get user permissions from their roles
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id UUID)
RETURNS SETOF TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.key
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON ur.role_id = rp.role_id
    JOIN public.permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = p_user_id
    UNION
    -- If user is admin, return all permissions
    SELECT p.key
    FROM public.permissions p
    WHERE (SELECT (auth.jwt()->>'role')::text) = 'admin';
END;
$$;

-- 14. Function to get user roles with permissions
CREATE OR REPLACE FUNCTION get_user_roles_with_permissions(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(role_with_perms) INTO result
    FROM (
        SELECT 
            r.id,
            r.name,
            r.description,
            r.is_system,
            jsonb_agg(DISTINCT jsonb_build_object('id', p.id, 'key', p.key, 'name', p.name, 'category', p.category)) as permissions
        FROM public.user_roles ur
        JOIN public.roles r ON ur.role_id = r.id
        LEFT JOIN public.role_permissions rp ON r.id = rp.role_id
        LEFT JOIN public.permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
        GROUP BY r.id, r.name, r.description, r.is_system
    ) role_with_perms;
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- 15. Function to list all roles with their permissions
CREATE OR REPLACE FUNCTION list_roles_with_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(role_with_perms) INTO result
    FROM (
        SELECT 
            r.id,
            r.name,
            r.description,
            r.is_system,
            jsonb_agg(DISTINCT jsonb_build_object('id', p.id, 'key', p.key, 'name', p.name, 'category', p.category)) as permissions
        FROM public.roles r
        LEFT JOIN public.role_permissions rp ON r.id = rp.role_id
        LEFT JOIN public.permissions p ON rp.permission_id = p.id
        GROUP BY r.id, r.name, r.description, r.is_system
        ORDER BY r.is_system DESC, r.name
    ) role_with_perms;
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- 16. Function to list all available permissions grouped by category
CREATE OR REPLACE FUNCTION list_all_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_object_agg(category, perms) INTO result
    FROM (
        SELECT 
            category,
            jsonb_agg(jsonb_build_object('id', id, 'key', key, 'name', name, 'description', description)) as perms
        FROM public.permissions
        GROUP BY category
        ORDER BY category
    ) grouped_perms;
    
    RETURN COALESCE(result, '{}'::jsonb);
END;
$$;

-- 17. Function to assign role to user
CREATE OR REPLACE FUNCTION assign_role_to_user(p_user_id UUID, p_role_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_roles (user_id, role_id, assigned_by)
    VALUES (p_user_id, p_role_id, auth.uid())
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    RETURN true;
END;
$$;

-- 18. Function to remove role from user
CREATE OR REPLACE FUNCTION remove_role_from_user(p_user_id UUID, p_role_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.user_roles
    WHERE user_id = p_user_id AND role_id = p_role_id;
    
    RETURN true;
END;
$$;

-- 19. Function to create custom role
CREATE OR REPLACE FUNCTION create_role(p_name TEXT, p_description TEXT, p_permission_keys TEXT[])
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    role_id UUID;
BEGIN
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

-- 20. Function to update role
CREATE OR REPLACE FUNCTION update_role(p_role_id UUID, p_name TEXT, p_description TEXT, p_permission_keys TEXT[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
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
