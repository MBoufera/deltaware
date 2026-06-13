-- Fix: create_role() had ambiguous "role_id" reference
-- The local variable "role_id" conflicted with the "role_id" column in role_permissions,
-- causing PostgreSQL error 42702. Renamed variable to "v_role_id".

CREATE OR REPLACE FUNCTION create_role(p_name TEXT, p_description TEXT, p_permission_keys TEXT[])
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role_id UUID;
BEGIN
    -- Check permission
    IF NOT check_user_permission('can_manage_roles') THEN
        RAISE EXCEPTION 'Insufficient permissions: can_manage_roles required' USING ERRCODE = '42501';
    END IF;

    -- Create the role
    INSERT INTO public.roles (name, description, created_by)
    VALUES (p_name, p_description, auth.uid())
    RETURNING id INTO v_role_id;

    -- Assign permissions to the role
    INSERT INTO public.role_permissions (role_id, permission_id)
    SELECT v_role_id, p.id
    FROM public.permissions p
    WHERE p.key = ANY(p_permission_keys)
    ON CONFLICT (role_id, permission_id) DO NOTHING;

    RETURN v_role_id;
END;
$$;
