import 'package:deltaware/core/constants/permissions_constants.dart';

class RoutePermissions {
  static const Map<String, AppPermission?> _routePermissionMap = {
    // Public routes (accessible to all authenticated users)
    '/dashboard': null, // Public - no special permission
    '/dashboard/pos': null, // Public - POS accessible to all
    
    // Admin only routes
    '/dashboard/users': null, // null = admin only
    '/dashboard/roles': null, // null = admin only
    '/dashboard/audit-logs': null, // Admin only
    
    // Permission-based routes
    '/dashboard/products': AppPermission.canManageProducts,
    '/dashboard/products/add': AppPermission.canManageProducts,
    '/dashboard/smart-batch': AppPermission.canManageProducts,
    '/dashboard/categories': AppPermission.canManageProducts,
    '/dashboard/stock': AppPermission.canManageProducts,
    
    '/dashboard/suppliers': AppPermission.canManageClients,
    
    '/dashboard/expenses': AppPermission.canManageSettings,
    
    '/dashboard/returns': AppPermission.canCancelSales,
    
    '/dashboard/documents': AppPermission.canViewAllSales,
    
    '/dashboard/analytics': AppPermission.canViewReports,
  };

  /// Get the required permission for a route
  /// Returns:
  /// - null: admin only
  /// - AppPermission: requires specific permission
  static AppPermission? getRequiredPermission(String route) {
    // Check if route is in the map
    if (_routePermissionMap.containsKey(route)) {
      return _routePermissionMap[route];
    }
    
    // Public routes
    if (route == '/dashboard' || route == '/dashboard/pos') {
      return null; // Public (no permission required)
    }
    
    return null; // Default to admin only for unknown routes
  }

  /// Check if a route requires admin access only
  static bool isAdminOnlyRoute(String route) {
    if (route == '/dashboard' || route == '/dashboard/pos') {
      return false; // Public routes
    }
    return getRequiredPermission(route) == null && _routePermissionMap.containsKey(route);
  }

  /// Check if a route is public (accessible to all authenticated users)
  static bool isPublicRoute(String route) {
    return route == '/dashboard' || route == '/dashboard/pos';
  }

  /// Get all protected routes
  static List<String> getProtectedRoutes() {
    return _routePermissionMap.entries
        .where((e) => e.value != null)
        .map((e) => e.key)
        .toList();
  }
}
