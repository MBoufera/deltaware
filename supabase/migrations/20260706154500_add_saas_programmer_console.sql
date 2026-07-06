-- Migration to add SaaS Programmer console helper RPC
CREATE OR REPLACE FUNCTION get_programmer_saas_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_super_admins JSONB;
    v_stores_list JSONB;
BEGIN
    -- 1. Fetch all super admins (store owners)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', u.id,
            'email', u.email,
            'full_name', COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown Owner'),
            'last_sign_in_at', u.last_sign_in_at,
            'created_at', u.created_at
        )
    ), '[]'::jsonb) INTO v_super_admins
    FROM auth.users u
    WHERE COALESCE((u.raw_user_meta_data->>'is_super_admin')::BOOLEAN, false) = true;

    -- 2. Fetch all stores with their members (including roles and user emails)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'name', s.name,
            'subtitle', s.subtitle,
            'created_at', s.created_at,
            'owner_id', s.created_by,
            'members', COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'id', u.id,
                            'email', u.email,
                            'full_name', COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown User'),
                            'role', sm.store_role,
                            'last_sign_in_at', u.last_sign_in_at
                        )
                    )
                    FROM public.store_members sm
                    JOIN auth.users u ON u.id = sm.user_id
                    WHERE sm.store_id = s.id
                ), '[]'::jsonb
            )
        )
    ), '[]'::jsonb) INTO v_stores_list
    FROM public.stores s;

    RETURN jsonb_build_object(
        'super_admins', v_super_admins,
        'stores', v_stores_list
    );
END;
$$;
