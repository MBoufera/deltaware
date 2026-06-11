enum AppPermission {
  canManageProducts,
  canManageClients,
  canViewAllSales,
  canCancelSales,
  canViewReports,
  canManageSettings,
  canManageUsers,
  canManageRoles,
  canManagePermissions,
  canViewAuditLogs,
}

extension AppPermissionX on AppPermission {
  /// Get the database key for this permission
  String get key {
    switch (this) {
      case AppPermission.canManageProducts:
        return 'can_manage_products';
      case AppPermission.canManageClients:
        return 'can_manage_clients';
      case AppPermission.canViewAllSales:
        return 'can_view_all_sales';
      case AppPermission.canCancelSales:
        return 'can_cancel_sales';
      case AppPermission.canViewReports:
        return 'can_view_reports';
      case AppPermission.canManageSettings:
        return 'can_manage_settings';
      case AppPermission.canManageUsers:
        return 'can_manage_users';
      case AppPermission.canManageRoles:
        return 'can_manage_roles';
      case AppPermission.canManagePermissions:
        return 'can_manage_permissions';
      case AppPermission.canViewAuditLogs:
        return 'can_view_audit_logs';
    }
  }

  /// Get the display name for UI
  String get displayName {
    switch (this) {
      case AppPermission.canManageProducts:
        return 'Manage Products';
      case AppPermission.canManageClients:
        return 'Manage Clients';
      case AppPermission.canViewAllSales:
        return 'View All Sales';
      case AppPermission.canCancelSales:
        return 'Cancel Sales';
      case AppPermission.canViewReports:
        return 'View Reports';
      case AppPermission.canManageSettings:
        return 'Manage Settings';
      case AppPermission.canManageUsers:
        return 'Manage Users';
      case AppPermission.canManageRoles:
        return 'Manage Roles';
      case AppPermission.canManagePermissions:
        return 'Manage Permissions';
      case AppPermission.canViewAuditLogs:
        return 'View Audit Logs';
    }
  }

  /// Get the description for help text
  String get description {
    switch (this) {
      case AppPermission.canManageProducts:
        return 'Create, update, and delete products';
      case AppPermission.canManageClients:
        return 'Manage client information and records';
      case AppPermission.canViewAllSales:
        return 'View sales records from all users';
      case AppPermission.canCancelSales:
        return 'Cancel and reverse sales transactions';
      case AppPermission.canViewReports:
        return 'Access analytics and reporting dashboards';
      case AppPermission.canManageSettings:
        return 'Modify application and store settings';
      case AppPermission.canManageUsers:
        return 'Create, update, and manage user accounts';
      case AppPermission.canManageRoles:
        return 'Create, update, delete, and assign roles';
      case AppPermission.canManagePermissions:
        return 'Configure permission system and policies';
      case AppPermission.canViewAuditLogs:
        return 'Access system audit and activity logs';
    }
  }

  /// Get the permission category
  String get category {
    switch (this) {
      case AppPermission.canManageProducts:
        return 'products';
      case AppPermission.canManageClients:
        return 'clients';
      case AppPermission.canViewAllSales:
      case AppPermission.canCancelSales:
        return 'sales';
      case AppPermission.canViewReports:
        return 'reports';
      case AppPermission.canManageSettings:
      case AppPermission.canManageUsers:
      case AppPermission.canManageRoles:
      case AppPermission.canManagePermissions:
      case AppPermission.canViewAuditLogs:
        return 'admin';
    }
  }

  /// Get the minimum role required for this permission
  String? get minimumRole {
    switch (this) {
      case AppPermission.canManageProducts:
        return 'Staff'; // Staff and higher
      case AppPermission.canManageClients:
        return 'Manager'; // Manager and higher
      case AppPermission.canViewAllSales:
        return 'Manager'; // Manager and higher
      case AppPermission.canCancelSales:
        return 'Manager'; // Manager and higher
      case AppPermission.canViewReports:
        return 'Staff'; // Staff and higher
      case AppPermission.canManageSettings:
        return 'Admin'; // Admin only
      case AppPermission.canManageUsers:
        return 'Admin'; // Admin only
      case AppPermission.canManageRoles:
        return 'Admin'; // Admin only
      case AppPermission.canManagePermissions:
        return 'Admin'; // Admin only
      case AppPermission.canViewAuditLogs:
        return 'Admin'; // Admin only
    }
  }
}

/// Helper class for permission operations
class PermissionRegistry {
  /// All available permissions
  static const List<AppPermission> all = AppPermission.values;

  /// Permissions grouped by category
  static Map<String, List<AppPermission>> get byCategory {
    final map = <String, List<AppPermission>>{};
    for (final permission in all) {
      map.putIfAbsent(permission.category, () => []).add(permission);
    }
    return map;
  }

  /// Permissions by minimum role
  static Map<String, List<AppPermission>> get byMinimumRole {
    final map = <String, List<AppPermission>>{};
    for (final permission in all) {
      final role = permission.minimumRole;
      if (role != null) {
        map.putIfAbsent(role, () => []).add(permission);
      }
    }
    return map;
  }

  /// Get permission from key string
  static AppPermission? fromKey(String key) {
    try {
      return all.firstWhere((p) => p.key == key);
    } catch (e) {
      return null;
    }
  }

  /// Permissions for each system role
  static List<AppPermission> getPermissionsForRole(String roleName) {
    switch (roleName) {
      case 'Admin':
        return all; // All permissions
      case 'Manager':
        return [
          AppPermission.canManageProducts,
          AppPermission.canManageClients,
          AppPermission.canViewAllSales,
          AppPermission.canCancelSales,
          AppPermission.canViewReports,
        ];
      case 'Staff':
        return [
          AppPermission.canManageProducts,
          AppPermission.canViewReports,
        ];
      case 'Viewer':
        return [
          AppPermission.canViewReports,
        ];
      default:
        return [];
    }
  }
}
