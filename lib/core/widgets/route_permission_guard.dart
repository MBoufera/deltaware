import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../config/route_permissions.dart';
import '../../features/auth/presentation/bloc/permissions_bloc.dart';
import '../../features/auth/presentation/bloc/permissions_state.dart';
import '../../features/admin/data/services/audit_service.dart';

/// Widget that protects routes based on permissions
/// Wraps route builders to enforce permission checks at the routing level
class RoutePermissionGuard extends StatefulWidget {
  final String route;
  final Widget child;

  const RoutePermissionGuard({
    super.key,
    required this.route,
    required this.child,
  });

  @override
  State<RoutePermissionGuard> createState() => _RoutePermissionGuardState();
}

class _RoutePermissionGuardState extends State<RoutePermissionGuard> {
  late AuditService _auditService;

  @override
  void initState() {
    super.initState();
    _auditService = AuditService();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsBloc, PermissionsState>(
      builder: (context, state) {
        // While loading, show a loading screen
        if (state.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user has permission to access this route
        if (_hasPermissionForRoute(state)) {
          return widget.child;
        }

        // User doesn't have permission - log and show access denied with specific error
        _logPermissionDenial(state);

        final errorInfo = _getErrorInfo(state);

        // User doesn't have permission - show access denied with specific message
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A2A32),
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Access Denied'),
          ),
          body: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 80, color: Colors.red.shade400),
                    const SizedBox(height: 24),
                    Text(
                      'Access Denied',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorInfo['message']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (errorInfo['suggestion'] != null)
                      Text(
                        errorInfo['suggestion']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (errorInfo['requiredPermission'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Required permission: ${errorInfo['requiredPermission']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Route: ${widget.route}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go Back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C5364),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (errorInfo['denialType'] == 'admin_only')
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Contact your administrator for access'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Request Access'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Get detailed error information based on denial reason
  Map<String, String?> _getErrorInfo(PermissionsState permissionsState) {
    final requiredPermission = RoutePermissions.getRequiredPermission(widget.route);

    // Admin only route
    if (requiredPermission == null && !RoutePermissions.isPublicRoute(widget.route)) {
      return {
        'denialType': 'admin_only',
        'message': 'This page is restricted to administrators only.',
        'suggestion': 'Contact your administrator if you believe this is an error.',
        'requiredPermission': 'Admin Role',
      };
    }

    // Missing specific permission
    if (requiredPermission != null) {
      final permDisplayName = requiredPermission.displayName;
      return {
        'denialType': 'missing_permission',
        'message': 'You do not have the required permission to access this page.',
        'suggestion': 'If you need access to this feature, contact your administrator.',
        'requiredPermission': permDisplayName,
      };
    }

    // Unknown error
    return {
      'denialType': 'unknown',
      'message': 'You do not have permission to access this page.',
      'suggestion': null,
      'requiredPermission': null,
    };
  }

  /// Log permission denial to audit service
  Future<void> _logPermissionDenial(PermissionsState permissionsState) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final requiredPermission = RoutePermissions.getRequiredPermission(widget.route);
      final denialReason = _getErrorInfo(permissionsState)['message'] ?? 'Access denied';

      await _auditService.logAction(
        adminId: user.id,
        action: 'permission_denied',
        resourceType: 'route',
        resourceId: widget.route,
        resourceName: widget.route,
        reason: 'Unauthorized access attempt: $denialReason',
        status: 'denied',
      );

      // For privilege escalation attempts (trying to access admin routes without admin role)
      if (requiredPermission == null &&
          !RoutePermissions.isPublicRoute(widget.route) &&
          !permissionsState.isAdmin) {
        await _auditService.logAction(
          adminId: user.id,
          action: 'escalation_attempt',
          resourceType: 'route',
          resourceId: widget.route,
          resourceName: widget.route,
          reason: 'Non-admin attempted to access admin route: ${widget.route}',
          status: 'denied',
        );
      }
    } catch (e) {
      // Silently fail to avoid interrupting UI with logging errors
      debugPrint('Error logging permission denial: $e');
    }
  }

  /// Check if the current user has permission to access this route
  bool _hasPermissionForRoute(PermissionsState permissionsState) {
    final requiredPermission = RoutePermissions.getRequiredPermission(widget.route);

    // Admin only route
    if (requiredPermission == null && !RoutePermissions.isPublicRoute(widget.route)) {
      return permissionsState.isAdmin;
    }

    // Public route - all authenticated users can access
    if (RoutePermissions.isPublicRoute(widget.route)) {
      return true;
    }

    // Admins bypass permission checks
    if (permissionsState.isAdmin) {
      return true;
    }

    // Check if user has the required permission
    if (requiredPermission != null) {
      return permissionsState.hasPermission(requiredPermission.key);
    }

    return false;
  }
}
