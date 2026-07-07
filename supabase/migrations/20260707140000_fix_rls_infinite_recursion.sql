-- Migration to fix RLS infinite recursion on public.stores and public.store_members

-- 1. Create helper security definer functions to bypass RLS recursion
CREATE OR REPLACE FUNCTION public.is_store_member(p_store_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.store_members
        WHERE store_id = p_store_id AND user_id = p_user_id
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_store_owner(p_store_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.stores
        WHERE id = p_store_id AND created_by = p_user_id
    );
END;
$$;

-- 2. Recreate public.stores policies to use security definer functions
DROP POLICY IF EXISTS "stores_select" ON public.stores;
CREATE POLICY "stores_select" ON public.stores FOR SELECT USING (
    created_by = auth.uid()
    OR public.is_store_member(id, auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

DROP POLICY IF EXISTS "stores_update" ON public.stores;
CREATE POLICY "stores_update" ON public.stores FOR UPDATE USING (
    created_by = auth.uid()
    -- Use public.is_store_admin (which is security definer) to check for admin role
    OR public.is_store_admin(id, auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

-- 3. Recreate public.store_members policies to use security definer functions
DROP POLICY IF EXISTS "store_members_select" ON public.store_members;
CREATE POLICY "store_members_select" ON public.store_members FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_store_member(store_id, auth.uid())
    OR public.is_store_owner(store_id, auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);

DROP POLICY IF EXISTS "store_members_manage" ON public.store_members;
CREATE POLICY "store_members_manage" ON public.store_members FOR ALL USING (
    public.is_store_admin(store_id, auth.uid())
    OR public.is_store_owner(store_id, auth.uid())
    OR COALESCE((auth.jwt()->'user_metadata'->>'is_programmer')::BOOLEAN, false) = true
);
