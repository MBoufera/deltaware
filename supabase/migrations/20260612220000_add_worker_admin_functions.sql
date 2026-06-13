-- User management admin functions
-- Adds update_worker_profile, generate_worker_password, delete_worker RPCs.
-- All functions use SECURITY DEFINER so they run with postgres privileges,
-- allowing direct access to auth.users (which is not accessible to the anon/authenticated role).

-- Ensure pgcrypto is available (needed for crypt() / gen_salt())
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─── 1. Update worker profile (name and/or email) ─────────────────────────

CREATE OR REPLACE FUNCTION update_worker_profile(
  p_user_id  UUID,
  p_full_name TEXT DEFAULT NULL,
  p_email     TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Permission gate
  IF NOT (
    (auth.jwt()->>'role')::text = 'admin'
    OR check_user_permission('can_manage_users')
  ) THEN
    RAISE EXCEPTION 'Insufficient permissions: can_manage_users required' USING ERRCODE = '42501';
  END IF;

  -- Cannot edit yourself via this function to avoid accidental lock-out
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Use your profile settings to update your own account';
  END IF;

  -- Update full name in user metadata
  IF p_full_name IS NOT NULL AND p_full_name != '' THEN
    UPDATE auth.users
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
                             || jsonb_build_object('full_name', p_full_name),
        updated_at = now()
    WHERE id = p_user_id;
  END IF;

  -- Update email (also sets email_confirmed_at to bypass re-confirmation)
  IF p_email IS NOT NULL AND p_email != '' THEN
    UPDATE auth.users
    SET email = lower(trim(p_email)),
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        updated_at = now()
    WHERE id = p_user_id;
  END IF;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION update_worker_profile TO authenticated;

-- ─── 2. Generate a new random password ────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_worker_password(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_password TEXT;
  v_upper    TEXT;
  v_lower    TEXT;
  v_digit    TEXT;
BEGIN
  -- Permission gate
  IF NOT (
    (auth.jwt()->>'role')::text = 'admin'
    OR check_user_permission('can_manage_users')
  ) THEN
    RAISE EXCEPTION 'Insufficient permissions: can_manage_users required' USING ERRCODE = '42501';
  END IF;

  -- Generate a readable 12-char password: 2 uppercase + 4 lowercase + 4 digits + !! suffix
  -- Pattern: e.g. "Mx4829rqkl!!" — easy to read, meets common complexity rules
  v_upper := chr(trunc(random() * 26)::int + 65) || chr(trunc(random() * 26)::int + 65);
  v_lower := chr(trunc(random() * 26)::int + 97)
          || chr(trunc(random() * 26)::int + 97)
          || chr(trunc(random() * 26)::int + 97)
          || chr(trunc(random() * 26)::int + 97);
  v_digit := chr(trunc(random() * 10)::int + 48)
          || chr(trunc(random() * 10)::int + 48)
          || chr(trunc(random() * 10)::int + 48)
          || chr(trunc(random() * 10)::int + 48);

  -- Interleave: Upper + digit + lower + digit + upper + lower + lower + digit + lower + digit + "!!"
  v_password := substr(v_upper, 1, 1)
             || substr(v_digit, 1, 1)
             || substr(v_lower, 1, 1)
             || substr(v_digit, 2, 1)
             || substr(v_upper, 2, 1)
             || substr(v_lower, 2, 1)
             || substr(v_lower, 3, 1)
             || substr(v_digit, 3, 1)
             || substr(v_lower, 4, 1)
             || substr(v_digit, 4, 1)
             || '!!';

  -- Hash and save
  UPDATE auth.users
  SET encrypted_password = crypt(v_password, gen_salt('bf')),
      updated_at = now()
  WHERE id = p_user_id;

  -- Return the plain-text password so the admin can share it with the worker
  RETURN v_password;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_worker_password TO authenticated;

-- ─── 3. Delete worker ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION delete_worker(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Permission gate
  IF NOT (
    (auth.jwt()->>'role')::text = 'admin'
    OR check_user_permission('can_manage_users')
  ) THEN
    RAISE EXCEPTION 'Insufficient permissions: can_manage_users required' USING ERRCODE = '42501';
  END IF;

  -- Prevent self-deletion
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot delete your own account' USING ERRCODE = '42501';
  END IF;

  -- Prevent deleting admins
  IF EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = p_user_id
      AND (raw_user_meta_data->>'role') = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin accounts cannot be deleted via this function' USING ERRCODE = '42501';
  END IF;

  -- Cascades handle user_roles, audit_logs (SET NULL), etc.
  DELETE FROM auth.users WHERE id = p_user_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_worker TO authenticated;
