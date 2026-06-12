-- Fix: get_audit_logs() return type mismatch (code 42804)
-- PostgreSQL cannot change return type with CREATE OR REPLACE — must DROP first.
-- admin_email and admin_name were VARCHAR but auth.users.email and COALESCE return TEXT.

-- Drop the old function so we can recreate with corrected return types
DROP FUNCTION IF EXISTS get_audit_logs(INT, INT, VARCHAR, UUID, VARCHAR, VARCHAR, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE);

CREATE OR REPLACE FUNCTION get_audit_logs(
  p_limit INT DEFAULT 100,
  p_offset INT DEFAULT 0,
  p_action VARCHAR DEFAULT NULL,
  p_admin_id UUID DEFAULT NULL,
  p_resource_type VARCHAR DEFAULT NULL,
  p_status VARCHAR DEFAULT NULL,
  p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  admin_id UUID,
  admin_email TEXT,          -- was VARCHAR; auth.users.email is TEXT
  admin_name TEXT,           -- was VARCHAR; COALESCE returns TEXT
  action VARCHAR,
  resource_type VARCHAR,
  resource_id UUID,
  resource_name VARCHAR,
  old_value JSONB,
  new_value JSONB,
  reason TEXT,
  status VARCHAR,
  error_message TEXT,
  ip_address INET,
  "timestamp" TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    al.id,
    al.admin_id,
    u.email,
    COALESCE(u.raw_user_meta_data->>'full_name', 'Unknown') as admin_name,
    al.action,
    al.resource_type,
    al.resource_id,
    al.resource_name,
    al.old_value,
    al.new_value,
    al.reason,
    al.status,
    al.error_message,
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
