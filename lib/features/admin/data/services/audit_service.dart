import 'package:supabase_flutter/supabase_flutter.dart';

/// Model for audit log entries
class AuditLog {
  final String id;
  final String adminId;
  final String? adminEmail;
  final String? adminName;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String? resourceName;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? reason;
  final String status;
  final String? errorMessage;
  final String? ipAddress;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.adminId,
    this.adminEmail,
    this.adminName,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.resourceName,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.status,
    this.errorMessage,
    this.ipAddress,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      adminEmail: json['admin_email'] as String?,
      adminName: json['admin_name'] as String?,
      action: json['action'] as String,
      resourceType: json['resource_type'] as String,
      resourceId: json['resource_id'] as String?,
      resourceName: json['resource_name'] as String?,
      oldValue: json['old_value'] as Map<String, dynamic>?,
      newValue: json['new_value'] as Map<String, dynamic>?,
      reason: json['reason'] as String?,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      ipAddress: json['ip_address'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'admin_id': adminId,
    'admin_email': adminEmail,
    'admin_name': adminName,
    'action': action,
    'resource_type': resourceType,
    'resource_id': resourceId,
    'resource_name': resourceName,
    'old_value': oldValue,
    'new_value': newValue,
    'reason': reason,
    'status': status,
    'error_message': errorMessage,
    'ip_address': ipAddress,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Model for audit statistics
class AuditStatistics {
  final String action;
  final int count;
  final int successCount;
  final int failedCount;
  final int deniedCount;

  AuditStatistics({
    required this.action,
    required this.count,
    required this.successCount,
    required this.failedCount,
    required this.deniedCount,
  });

  factory AuditStatistics.fromJson(Map<String, dynamic> json) {
    return AuditStatistics(
      action: json['action'] as String,
      count: json['count'] as int,
      successCount: json['success_count'] as int,
      failedCount: json['failed_count'] as int,
      deniedCount: json['denied_count'] as int,
    );
  }
}

/// Service for audit logging operations
class AuditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Log an audit action
  /// [p_admin_id] - ID of the admin performing the action
  /// [p_action] - Type of action (assign_role, update_role, etc.)
  /// [p_resource_type] - Type of resource being affected (user, role, permission)
  /// [p_resource_id] - ID of the affected resource
  /// [p_resource_name] - Name of the affected resource for readability
  /// [p_old_value] - Previous state (for updates)
  /// [p_new_value] - New state (for creates/updates)
  /// [p_reason] - Reason for the change
  /// [p_status] - Status of the action (success, failed, denied)
  /// [p_error_message] - Error details if failed
  /// [p_ip_address] - IP address of the admin
  Future<String?> logAction({
    required String adminId,
    required String action,
    required String resourceType,
    String? resourceId,
    String? resourceName,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? reason,
    String status = 'success',
    String? errorMessage,
    String? ipAddress,
  }) async {
    try {
      final response = await _supabase.rpc(
        'log_audit_action',
        params: {
          'p_admin_id': adminId,
          'p_action': action,
          'p_resource_type': resourceType,
          'p_resource_id': resourceId,
          'p_resource_name': resourceName,
          'p_old_value': oldValue,
          'p_new_value': newValue,
          'p_reason': reason,
          'p_status': status,
          'p_error_message': errorMessage,
          'p_ip_address': ipAddress,
        },
      );
      return response as String?;
    } catch (e) {
      print('Error logging audit action: $e');
      rethrow;
    }
  }

  /// Get audit logs with filtering and pagination
  Future<List<AuditLog>> getAuditLogs({
    int limit = 100,
    int offset = 0,
    String? action,
    String? adminId,
    String? resourceType,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_audit_logs',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_action': action,
          'p_admin_id': adminId,
          'p_resource_type': resourceType,
          'p_status': status,
          'p_start_date': startDate?.toIso8601String(),
          'p_end_date': endDate?.toIso8601String(),
        },
      ) as List;

      return response
          .map((item) => AuditLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching audit logs: $e');
      rethrow;
    }
  }

  /// Get total count of audit logs matching criteria
  Future<int> getAuditLogsCount({
    String? action,
    String? adminId,
    String? resourceType,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_audit_logs_count',
        params: {
          'p_action': action,
          'p_admin_id': adminId,
          'p_resource_type': resourceType,
          'p_status': status,
          'p_start_date': startDate?.toIso8601String(),
          'p_end_date': endDate?.toIso8601String(),
        },
      );
      return response as int;
    } catch (e) {
      print('Error fetching audit logs count: $e');
      rethrow;
    }
  }

  /// Get audit statistics for the past N days
  Future<List<AuditStatistics>> getAuditStatistics({int days = 7}) async {
    try {
      final response = await _supabase.rpc(
        'get_audit_statistics',
        params: {'p_days': days},
      ) as List;

      return response
          .map((item) => AuditStatistics.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching audit statistics: $e');
      rethrow;
    }
  }

  /// Log a role assignment (convenience method)
  Future<String?> logRoleAssignment({
    required String adminId,
    required String userId,
    required String userEmail,
    required String roleId,
    required String roleName,
    String? reason,
  }) async {
    return logAction(
      adminId: adminId,
      action: 'assign_role',
      resourceType: 'user_role',
      resourceId: userId,
      resourceName: userEmail,
      newValue: {'role_id': roleId, 'role_name': roleName},
      reason: reason ?? 'Role assignment',
    );
  }

  /// Log a permission denial (security event)
  Future<String?> logPermissionDenial({
    required String userId,
    required String permission,
    required String resource,
    String? reason,
    String? ipAddress,
  }) async {
    return logAction(
      adminId: userId,
      action: 'permission_denied',
      resourceType: resource,
      reason: reason ?? 'Permission denied for $permission',
      status: 'denied',
      ipAddress: ipAddress,
    );
  }

  /// Log a privilege escalation attempt (security event)
  Future<String?> logPrivilegeEscalationAttempt({
    required String userId,
    required String attemptedRole,
    String? reason,
    String? ipAddress,
  }) async {
    return logAction(
      adminId: userId,
      action: 'privilege_escalation_attempt',
      resourceType: 'user',
      resourceId: userId,
      reason: reason ?? 'Attempted to escalate to $attemptedRole',
      status: 'denied',
      ipAddress: ipAddress,
    );
  }
}
