enum PermissionGranularity {
  /// User can only view/read data
  view,
  /// User can view and edit data
  edit,
  /// User has full control including delete
  manage,
}

enum ResourceScope {
  /// User can only access own resources (e.g., own sales)
  own,
  /// User can access department resources
  department,
  /// User can access all resources
  all,
}

/// Extended permission with additional metadata
class ExtendedPermission {
  /// Base permission key (e.g., 'canManageProducts')
  final String key;
  
  /// Granularity level (view/edit/manage)
  final PermissionGranularity granularity;
  
  /// Resource scope (own/department/all)
  final ResourceScope resourceScope;
  
  /// Optional: Permission valid only during business hours
  final bool requiresBusinessHours;
  
  /// Optional: Time-based permission expiry (null = no expiry)
  final DateTime? expiresAt;
  
  /// Optional: Requires additional authentication
  final bool requiresAdditionalAuth;
  
  /// Optional: Requires approval for sensitive operations
  final bool requiresApproval;
  
  /// Optional: Metadata (custom conditions, department, etc.)
  final Map<String, dynamic>? metadata;

  ExtendedPermission({
    required this.key,
    this.granularity = PermissionGranularity.view,
    this.resourceScope = ResourceScope.own,
    this.requiresBusinessHours = false,
    this.expiresAt,
    this.requiresAdditionalAuth = false,
    this.requiresApproval = false,
    this.metadata,
  });

  /// Check if permission is currently valid
  bool isValid() {
    // Check expiry
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
      return false;
    }

    // Check business hours if required
    if (requiresBusinessHours) {
      final now = DateTime.now();
      final hour = now.hour;
      // Business hours: 8 AM to 6 PM
      if (hour < 8 || hour >= 18) {
        return false;
      }
    }

    return true;
  }

  /// Check if user can perform a specific action
  bool canPerformAction(PermissionAction action) {
    if (!isValid()) return false;

    switch (action) {
      case PermissionAction.view:
        return granularity != PermissionGranularity.view ||
            granularity == PermissionGranularity.edit ||
            granularity == PermissionGranularity.manage;
      case PermissionAction.edit:
        return granularity == PermissionGranularity.edit ||
            granularity == PermissionGranularity.manage;
      case PermissionAction.delete:
        return granularity == PermissionGranularity.manage;
      case PermissionAction.approve:
        return granularity == PermissionGranularity.manage;
    }
  }

  /// Check if user can access a specific resource
  bool canAccessResource(String resourceId, String ownerId, {String? departmentId}) {
    if (!isValid()) return false;

    switch (resourceScope) {
      case ResourceScope.own:
        return resourceId == ownerId;
      case ResourceScope.department:
        // Check if user's department matches resource department
        final userDept = metadata?['department'] as String?;
        return userDept != null && userDept == departmentId;
      case ResourceScope.all:
        return true;
    }
  }

  /// Get effective permission level as string (for logging)
  String getEffectiveLevel() {
    if (!isValid()) return 'expired';
    if (requiresAdditionalAuth) return '${granularity.name}_with_auth';
    if (requiresApproval) return '${granularity.name}_with_approval';
    return granularity.name;
  }

  @override
  String toString() =>
      'ExtendedPermission($key, ${granularity.name}/${resourceScope.name}, valid=${isValid()})';
}

/// Permission actions with granularity
enum PermissionAction {
  /// View/read data
  view,
  /// Edit/modify data
  edit,
  /// Delete data
  delete,
  /// Approve/authorize actions
  approve,
}

/// Helper class for permission evaluation
class PermissionEvaluator {
  /// Check if user has permission for specific action on resource
  static bool canPerformAction(
    ExtendedPermission permission,
    PermissionAction action, {
    String? resourceId,
    String? ownerId,
    String? departmentId,
  }) {
    // Check action granularity
    if (!permission.canPerformAction(action)) return false;

    // Check resource access if specified
    if (resourceId != null && ownerId != null) {
      if (!permission.canAccessResource(resourceId, ownerId, departmentId: departmentId)) {
        return false;
      }
    }

    // Check if approval required
    if (permission.requiresApproval) {
      // Would need approval flow in UI
      return false;
    }

    return true;
  }

  /// Check if permission expires soon (within N hours)
  static bool expiresSoon(ExtendedPermission permission, {int withinHours = 24}) {
    if (permission.expiresAt == null) return false;
    
    final now = DateTime.now();
    final difference = permission.expiresAt!.difference(now).inHours;
    return difference > 0 && difference <= withinHours;
  }

  /// Get permission status with reason if invalid
  static PermissionStatus checkPermissionStatus(ExtendedPermission permission) {
    if (!permission.isValid()) {
      if (permission.expiresAt != null && DateTime.now().isAfter(permission.expiresAt!)) {
        return PermissionStatus(valid: false, reason: 'Permission has expired');
      }
      if (permission.requiresBusinessHours) {
        return PermissionStatus(
          valid: false,
          reason: 'Permission only valid during business hours (8 AM - 6 PM)',
        );
      }
    }

    if (permission.requiresAdditionalAuth) {
      return PermissionStatus(valid: true, reason: 'Requires additional authentication');
    }

    if (permission.requiresApproval) {
      return PermissionStatus(valid: true, reason: 'Requires approval for sensitive actions');
    }

    return PermissionStatus(valid: true, reason: 'Permission granted');
  }
}

/// Permission status with reason
class PermissionStatus {
  final bool valid;
  final String reason;

  PermissionStatus({required this.valid, required this.reason});

  @override
  String toString() => '$reason (${valid ? 'valid' : 'invalid'})';
}

/// Extended permission presets for common use cases
class ExtendedPermissionPresets {
  /// Full analytics access with all operations
  static ExtendedPermission analyticsManager() => ExtendedPermission(
    key: 'canViewReports',
    granularity: PermissionGranularity.manage,
    resourceScope: ResourceScope.all,
  );

  /// Read-only analytics access
  static ExtendedPermission analyticsViewer() => ExtendedPermission(
    key: 'canViewReports',
    granularity: PermissionGranularity.view,
    resourceScope: ResourceScope.all,
  );

  /// Product management - own department only
  static ExtendedPermission productManagerDept() => ExtendedPermission(
    key: 'canManageProducts',
    granularity: PermissionGranularity.edit,
    resourceScope: ResourceScope.department,
  );

  /// Product management - all products
  static ExtendedPermission productManagerAll() => ExtendedPermission(
    key: 'canManageProducts',
    granularity: PermissionGranularity.manage,
    resourceScope: ResourceScope.all,
  );

  /// View own sales only
  static ExtendedPermission salesViewOwn() => ExtendedPermission(
    key: 'canViewAllSales',
    granularity: PermissionGranularity.view,
    resourceScope: ResourceScope.own,
  );

  /// View all sales
  static ExtendedPermission salesViewAll() => ExtendedPermission(
    key: 'canViewAllSales',
    granularity: PermissionGranularity.view,
    resourceScope: ResourceScope.all,
  );

  /// Temporary admin access (24 hours)
  static ExtendedPermission temporaryAdmin() => ExtendedPermission(
    key: 'admin',
    granularity: PermissionGranularity.manage,
    resourceScope: ResourceScope.all,
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
    requiresAdditionalAuth: true,
  );

  /// Business hours only manager access
  static ExtendedPermission businessHoursManager() => ExtendedPermission(
    key: 'canManageUsers',
    granularity: PermissionGranularity.edit,
    resourceScope: ResourceScope.department,
    requiresBusinessHours: true,
  );
}
