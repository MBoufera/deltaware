-- Audit Logging System
-- Tracks all permission changes, role assignments, and admin actions

-- Create audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action VARCHAR(50) NOT NULL, -- assign_role, remove_role, edit_role, create_role, update_role, delete_role, edit_permissions, etc.
  resource_type VARCHAR(50) NOT NULL, -- user, role, permission, setting, etc.
  resource_id UUID, -- ID of the affected resource (user_id, role_id, etc.)
  resource_name VARCHAR(255), -- Name of the affected resource for readability
  old_value JSONB, -- Previous state (for updates)
  new_value JSONB, -- New state (for creates/updates)
  reason TEXT, -- Admin's reason for the change
  status VARCHAR(20) DEFAULT 'success', -- success, failed, denied
  error_message TEXT, -- Error details if failed
  ip_address INET, -- IP address of the admin
  user_agent TEXT, -- Browser/client info
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT valid_action CHECK (action IN (
    'assign_role', 'remove_role', 'create_role', 'update_role', 'delete_role',
    'edit_permissions', 'create_user', 'update_user', 'delete_user',
    'create_setting', 'update_setting', 'delete_setting',
    'permission_denied', 'privilege_escalation_attempt'
  )),
  CONSTRAINT valid_status CHECK (status IN ('success', 'failed', 'denied'))
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_id ON audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource_id ON audit_logs(resource_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs(status);

-- Audit log function to be called when logging actions
CREATE OR REPLACE FUNCTION log_audit_action(
  p_admin_id UUID,
  p_action VARCHAR,
  p_resource_type VARCHAR,
  p_resource_id UUID,
  p_resource_name VARCHAR,
  p_old_value JSONB,
  p_new_value JSONB,
  p_reason TEXT,
  p_status VARCHAR DEFAULT 'success',
  p_error_message TEXT DEFAULT NULL,
  p_ip_address INET DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO audit_logs (
    admin_id, action, resource_type, resource_id, resource_name,
    old_value, new_value, reason, status, error_message, ip_address
  ) VALUES (
    p_admin_id, p_action, p_resource_type, p_resource_id, p_resource_name,
    p_old_value, p_new_value, p_reason, p_status, p_error_message, p_ip_address
  )
  RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC function to get audit logs with filtering
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
  admin_email TEXT,
  admin_name TEXT,
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

-- RPC function to get audit logs count
CREATE OR REPLACE FUNCTION get_audit_logs_count(
  p_action VARCHAR DEFAULT NULL,
  p_admin_id UUID DEFAULT NULL,
  p_resource_type VARCHAR DEFAULT NULL,
  p_status VARCHAR DEFAULT NULL,
  p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS INT AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*)
  INTO v_count
  FROM audit_logs
  WHERE
    (p_action IS NULL OR action = p_action) AND
    (p_admin_id IS NULL OR admin_id = p_admin_id) AND
    (p_resource_type IS NULL OR resource_type = p_resource_type) AND
    (p_status IS NULL OR status = p_status) AND
    (p_start_date IS NULL OR timestamp >= p_start_date) AND
    (p_end_date IS NULL OR timestamp <= p_end_date);
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC function to get audit statistics (useful for dashboard)
CREATE OR REPLACE FUNCTION get_audit_statistics(
  p_days INT DEFAULT 7
) RETURNS TABLE (
  action VARCHAR,
  count INT,
  success_count INT,
  failed_count INT,
  denied_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    al.action,
    COUNT(*)::INT as count,
    COUNT(CASE WHEN al.status = 'success' THEN 1 END)::INT as success_count,
    COUNT(CASE WHEN al.status = 'failed' THEN 1 END)::INT as failed_count,
    COUNT(CASE WHEN al.status = 'denied' THEN 1 END)::INT as denied_count
  FROM audit_logs al
  WHERE al.timestamp >= CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
  GROUP BY al.action
  ORDER BY count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to log role assignments
CREATE OR REPLACE FUNCTION log_role_assignment() RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    PERFORM log_audit_action(
      auth.uid(),
      'assign_role',
      'user_role',
      NEW.user_id,
      (SELECT email FROM auth.users WHERE id = NEW.user_id),
      NULL,
      jsonb_build_object('role_id', NEW.role_id, 'assigned_at', NEW.assigned_at),
      'Role assignment',
      'success'
    );
  ELSIF (TG_OP = 'DELETE') THEN
    PERFORM log_audit_action(
      auth.uid(),
      'remove_role',
      'user_role',
      OLD.user_id,
      (SELECT email FROM auth.users WHERE id = OLD.user_id),
      jsonb_build_object('role_id', OLD.role_id),
      NULL,
      'Role removal',
      'success'
    );
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for user_roles
DROP TRIGGER IF EXISTS trigger_log_user_roles ON user_roles;
CREATE TRIGGER trigger_log_user_roles
AFTER INSERT OR DELETE ON user_roles
FOR EACH ROW EXECUTE FUNCTION log_role_assignment();

-- Trigger to log role updates
CREATE OR REPLACE FUNCTION log_role_changes() RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    PERFORM log_audit_action(
      auth.uid(),
      'create_role',
      'role',
      NEW.id,
      NEW.name,
      NULL,
      jsonb_build_object('name', NEW.name, 'description', NEW.description, 'is_system', NEW.is_system),
      'New role created',
      'success'
    );
  ELSIF (TG_OP = 'UPDATE') THEN
    IF (NEW.name != OLD.name OR NEW.description != OLD.description) THEN
      PERFORM log_audit_action(
        auth.uid(),
        'update_role',
        'role',
        NEW.id,
        NEW.name,
        jsonb_build_object('name', OLD.name, 'description', OLD.description),
        jsonb_build_object('name', NEW.name, 'description', NEW.description),
        'Role updated',
        'success'
      );
    END IF;
  ELSIF (TG_OP = 'DELETE') THEN
    PERFORM log_audit_action(
      auth.uid(),
      'delete_role',
      'role',
      OLD.id,
      OLD.name,
      jsonb_build_object('name', OLD.name, 'description', OLD.description, 'is_system', OLD.is_system),
      NULL,
      'Role deleted',
      'success'
    );
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for roles
DROP TRIGGER IF EXISTS trigger_log_role_changes ON roles;
CREATE TRIGGER trigger_log_role_changes
AFTER INSERT OR UPDATE OR DELETE ON roles
FOR EACH ROW EXECUTE FUNCTION log_role_changes();

-- Trigger to log permission assignments
CREATE OR REPLACE FUNCTION log_permission_assignment() RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    PERFORM log_audit_action(
      auth.uid(),
      'edit_permissions',
      'role_permission',
      NEW.role_id,
      (SELECT name FROM roles WHERE id = NEW.role_id),
      NULL,
      jsonb_build_object('permission_id', NEW.permission_id, 'permission_key', (SELECT key FROM permissions WHERE id = NEW.permission_id)),
      'Permission added to role',
      'success'
    );
  ELSIF (TG_OP = 'DELETE') THEN
    PERFORM log_audit_action(
      auth.uid(),
      'edit_permissions',
      'role_permission',
      OLD.role_id,
      (SELECT name FROM roles WHERE id = OLD.role_id),
      jsonb_build_object('permission_id', OLD.permission_id, 'permission_key', (SELECT key FROM permissions WHERE id = OLD.permission_id)),
      NULL,
      'Permission removed from role',
      'success'
    );
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for role_permissions
DROP TRIGGER IF EXISTS trigger_log_permission_assignment ON role_permissions;
CREATE TRIGGER trigger_log_permission_assignment
AFTER INSERT OR DELETE ON role_permissions
FOR EACH ROW EXECUTE FUNCTION log_permission_assignment();

-- Grant permissions to authenticated users (for reading audit logs they have access to)
GRANT SELECT ON audit_logs TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_logs TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_logs_count TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_statistics TO authenticated;
GRANT EXECUTE ON FUNCTION log_audit_action TO authenticated;
