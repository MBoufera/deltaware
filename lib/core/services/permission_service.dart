import 'package:deltaware/core/constants/extended_permissions.dart';

/// Service for evaluating permissions with extended features
class PermissionService {
  /// Map of extended permissions per user
  final Map<String, ExtendedPermission> _extendedPermissions = {};

  /// Register an extended permission for a user
  void registerExtendedPermission(String userId, ExtendedPermission permission) {
    _extendedPermissions['$userId:${permission.key}'] = permission;
  }

  /// Check if user has basic permission (from PermissionsState)
  bool hasBasicPermission(Map<String, dynamic> permissions, String key) {
    return permissions[key] == true;
  }

  /// Check if user has extended permission
  ExtendedPermission? getExtendedPermission(String userId, String permissionKey) {
    return _extendedPermissions['$userId:$permissionKey'];
  }

  /// Check if user can perform action with extended checks
  bool canPerformAction(
    String userId,
    String permissionKey,
    PermissionAction action, {
    String? resourceId,
    String? ownerId,
    String? departmentId,
  }) {
    final extendedPerm = getExtendedPermission(userId, permissionKey);
    
    if (extendedPerm != null) {
      return PermissionEvaluator.canPerformAction(
        extendedPerm,
        action,
        resourceId: resourceId,
        ownerId: ownerId,
        departmentId: departmentId,
      );
    }

    // Fallback to basic permission check
    return true;
  }

  /// Get permission status with detailed info
  PermissionStatus getPermissionStatus(String userId, String permissionKey) {
    final extendedPerm = getExtendedPermission(userId, permissionKey);
    
    if (extendedPerm != null) {
      return PermissionEvaluator.checkPermissionStatus(extendedPerm);
    }

    return PermissionStatus(valid: true, reason: 'Basic permission granted');
  }

  /// Check if permission expires soon
  bool expiresSoon(String userId, String permissionKey, {int withinHours = 24}) {
    final extendedPerm = getExtendedPermission(userId, permissionKey);
    
    if (extendedPerm != null) {
      return PermissionEvaluator.expiresSoon(extendedPerm, withinHours: withinHours);
    }

    return false;
  }

  /// Get all valid permissions for a user
  List<ExtendedPermission> getValidExtendedPermissions(String userId) {
    return _extendedPermissions.entries
        .where((e) => e.key.startsWith('$userId:') && e.value.isValid())
        .map((e) => e.value)
        .toList();
  }

  /// Get permissions expiring soon
  List<ExtendedPermission> getExpiringPermissions(String userId, {int withinHours = 24}) {
    return _extendedPermissions.entries
        .where((e) =>
            e.key.startsWith('$userId:') &&
            PermissionEvaluator.expiresSoon(e.value, withinHours: withinHours))
        .map((e) => e.value)
        .toList();
  }

  /// Clear all extended permissions for a user (e.g., on logout)
  void clearUserPermissions(String userId) {
    _extendedPermissions.removeWhere((key, _) => key.startsWith('$userId:'));
  }

  /// Clear all permissions
  void clearAll() {
    _extendedPermissions.clear();
  }
}

/// Singleton instance
final permissionService = PermissionService();
