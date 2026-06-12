-- Fix 1: Allow editing permissions on system roles (but still protect their name/description)
-- Fix 2: Add missing permissions that exist in the app but are not in the permissions table

-- Update the update_role function to allow permission changes on system roles
CREATE OR REPLACE FUNCTION update_role(p_role_id UUID, p_name TEXT, p_description TEXT, p_permission_keys TEXT[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_system BOOLEAN;
BEGIN
    -- Check permission
    IF NOT check_user_permission('can_manage_roles') THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_roles required' USING ERRCODE = '403';
    END IF;

    SELECT is_system INTO v_is_system FROM public.roles WHERE id = p_role_id;

    -- For system roles: only update permissions, not name/description
    IF v_is_system THEN
        -- Remove existing permissions
        DELETE FROM public.role_permissions WHERE role_id = p_role_id;

        -- Add new permissions
        INSERT INTO public.role_permissions (role_id, permission_id)
        SELECT p_role_id, p.id
        FROM public.permissions p
        WHERE p.key = ANY(p_permission_keys)
        ON CONFLICT (role_id, permission_id) DO NOTHING;

        RETURN true;
    END IF;

    -- For custom roles: update everything
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

-- Fix 2: Insert all missing permissions
INSERT INTO public.permissions (key, name, description, category) VALUES
    -- Suppliers
    ('can_manage_suppliers', 'Manage Suppliers', 'Create, update, and manage supplier records', 'suppliers'),
    ('can_view_suppliers', 'View Suppliers', 'View supplier list and details', 'suppliers'),

    -- Stock / Inventory
    ('can_manage_stock', 'Manage Stock', 'Add stock entries and manage inventory levels', 'inventory'),
    ('can_view_stock', 'View Stock', 'View inventory and stock levels', 'inventory'),
    ('can_manage_batches', 'Manage Batches', 'Create and manage product batches', 'inventory'),

    -- Expenses
    ('can_manage_expenses', 'Manage Expenses', 'Create, update, and delete expense records', 'expenses'),
    ('can_view_expenses', 'View Expenses', 'View expense records and summaries', 'expenses'),

    -- Returns
    ('can_manage_returns', 'Manage Returns', 'Process and manage product returns', 'returns'),
    ('can_view_returns', 'View Returns', 'View return records', 'returns'),

    -- Sales / POS
    ('can_create_sales', 'Create Sales', 'Create new sales transactions at POS', 'sales'),
    ('can_apply_discounts', 'Apply Discounts', 'Apply discounts during sales', 'sales'),
    ('can_view_pos', 'Access POS', 'Access the point-of-sale screen', 'sales'),

    -- Documents
    ('can_view_documents', 'View Documents', 'View document history and records', 'documents'),
    ('can_manage_documents', 'Manage Documents', 'Create and manage documents', 'documents'),

    -- Analytics
    ('can_view_analytics', 'View Analytics', 'Access analytics and statistics dashboards', 'reports'),

    -- Categories
    ('can_manage_categories', 'Manage Categories', 'Create and manage product categories', 'products')

ON CONFLICT (key) DO NOTHING;
