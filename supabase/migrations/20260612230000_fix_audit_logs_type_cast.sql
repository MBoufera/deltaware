-- Fix get_audit_logs() column 3 type mismatch (code 42804)
-- Problem: auth.users.email is character varying(255), but RETURNS TABLE declares admin_email TEXT.
-- PostgreSQL won't auto-cast varchar(255) to text in function return types.
-- Fix: explicitly cast u.email::text and resource_name::text in the SELECT.
-- Must DROP first since return type is changing.

DROP FUNCTION IF EXISTS get_audit_logs(INT, INT, VARCHAR, UUID, VARCHAR, VARCHAR, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE);

CREATE OR REPLACE FUNCTION get_audit_logs(
  p_limit         INT DEFAULT 100,
  p_offset        INT DEFAULT 0,
  p_action        VARCHAR DEFAULT NULL,
  p_admin_id      UUID DEFAULT NULL,
  p_resource_type VARCHAR DEFAULT NULL,
  p_status        VARCHAR DEFAULT NULL,
  p_start_date    TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_end_date      TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS TABLE (
  id            UUID,
  admin_id      UUID,
  admin_email   TEXT,
  admin_name    TEXT,
  action        TEXT,
  resource_type TEXT,
  resource_id   UUID,
  resource_name TEXT,
  old_value     JSONB,
  new_value     JSONB,
  reason        TEXT,
  status        TEXT,
  error_message TEXT,
  ip_address    INET,
  "timestamp"   TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    al.id,
    al.admin_id,
    u.email::text,                                                       -- cast varchar(255) → text
    COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown')::text,       -- already text, cast for safety
    al.action::text,
    al.resource_type::text,
    al.resource_id,
    al.resource_name::text,
    al.old_value,
    al.new_value,
    al.reason::text,
    al.status::text,
    al.error_message::text,
    al.ip_address,
    al.timestamp
  FROM audit_logs al
  LEFT JOIN auth.users u ON al.admin_id = u.id
  WHERE
    (p_action IS NULL OR al.action = p_action) AND
    (p_admin_id IS NULL OR al.admin_id = p_admin_id) AND
    (p_resource_type IS NULL OR al.resource_type = p_resource_type) AND
    (p_status IS NULL OR al.status = p_status) AND
    (p_start_date IS NULL OR al.timestamp >= p_start_date) AND
    (p_end_date IS NULL OR al.timestamp <= p_end_date)
  ORDER BY al.timestamp DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_audit_logs TO authenticated;
