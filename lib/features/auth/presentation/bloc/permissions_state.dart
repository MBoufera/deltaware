import 'package:deltaware/core/constants/extended_permissions.dart';
import 'package:deltaware/core/services/permission_service.dart';

class PermissionsState {
  final bool isLoading;
  final bool isAdmin;
  final Map<String, dynamic> permissions;
  final DateTime? lastLoadedAt;
  final int cacheExpirySeconds;
  final String? userId; // Current user ID for extended permissions

  PermissionsState({
    this.isLoading = true,
    this.isAdmin = false,
    this.permissions = const {},
    this.lastLoadedAt,
    this.cacheExpirySeconds = 3600, // 1 hour default
    this.userId,
  });

  /// Check if cached permissions have expired
  bool isCacheExpired() {
    if (lastLoadedAt == null) return true;
    final now = DateTime.now();
    final difference = now.difference(lastLoadedAt!).inSeconds;
    return difference > cacheExpirySeconds;
  }

  bool hasPermission(String key) {
    if (isAdmin) return true;
    return permissions[key] == true;
  }

  /// Check if user can perform specific action with extended permissions
  bool canPerformAction(
    String permissionKey,
    PermissionAction action, {
    String? resourceId,
    String? ownerId,
    String? departmentId,
  }) {
    if (isAdmin) return true;
    if (userId == null) return false;

    return permissionService.canPerformAction(
      userId!,
      permissionKey,
      action,
      resourceId: resourceId,
      ownerId: ownerId,
      departmentId: departmentId,
    );
  }

  /// Get detailed permission status (valid/invalid with reason)
  PermissionStatus getPermissionStatus(String permissionKey) {
    if (isAdmin) return PermissionStatus(valid: true, reason: 'Admin user');
    if (userId == null) return PermissionStatus(valid: false, reason: 'No user ID');

    return permissionService.getPermissionStatus(userId!, permissionKey);
  }

  /// Check if permission expires soon (within N hours)
  bool permissionExpiresSoon(String permissionKey, {int withinHours = 24}) {
    if (userId == null) return false;
    return permissionService.expiresSoon(userId!, permissionKey, withinHours: withinHours);
  }

  /// Get extended permission details if available
  ExtendedPermission? getExtendedPermission(String permissionKey) {
    if (userId == null) return null;
    return permissionService.getExtendedPermission(userId!, permissionKey);
  }

  PermissionsState copyWith({
    bool? isLoading,
    bool? isAdmin,
    Map<String, dynamic>? permissions,
    DateTime? lastLoadedAt,
    int? cacheExpirySeconds,
    String? userId,
  }) {
    return PermissionsState(
      isLoading: isLoading ?? this.isLoading,
      isAdmin: isAdmin ?? this.isAdmin,
      permissions: permissions ?? this.permissions,
      lastLoadedAt: lastLoadedAt ?? this.lastLoadedAt,
      cacheExpirySeconds: cacheExpirySeconds ?? this.cacheExpirySeconds,
      userId: userId ?? this.userId,
    );
  }
}
