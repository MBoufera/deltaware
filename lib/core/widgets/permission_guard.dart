import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/permissions_constants.dart';
import '../../features/auth/presentation/bloc/permissions_bloc.dart';
import '../../features/auth/presentation/bloc/permissions_state.dart';
import '../../features/admin/data/services/audit_service.dart';

class PermissionGuard extends StatefulWidget {
  final String requiredPermission;
  final Widget child;
  final Widget? fallback; // Optional: specific fallback UI
  final String? componentName; // Optional: name of component for logging

  const PermissionGuard({
    super.key,
    required this.requiredPermission,
    required this.child,
    this.fallback,
    this.componentName,
  });

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard> {
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
        if (state.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state.hasPermission(widget.requiredPermission)) {
          return widget.child;
        }

        // Log permission denial
        _logPermissionDenial(state);

        return widget.fallback ?? _buildAccessDenied(context, state);
      },
    );
  }

  /// Log permission denial to audit service
  Future<void> _logPermissionDenial(PermissionsState permissionsState) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Find the permission that matches requiredPermission
      String permissionName = widget.requiredPermission;
      try {
        final permission = AppPermission.values.firstWhere(
          (p) => p.key == widget.requiredPermission,
          orElse: () => AppPermission.canManageProducts,
        );
        permissionName = permission.displayName;
      } catch (_) {}

      await _auditService.logAction(
        adminId: user.id,
        action: 'permission_denied_widget',
        resourceType: 'component',
        resourceId: widget.componentName ?? 'unknown',
        resourceName: widget.componentName ?? 'Unknown Component',
        reason: 'User attempted to access component requiring: $permissionName',
        status: 'denied',
      );
    } catch (e) {
      debugPrint('Error logging permission denial: $e');
    }
  }

  Widget _buildAccessDenied(BuildContext context, PermissionsState state) {
    // Find matching permission to get display name
    String permissionDisplayName = widget.requiredPermission;
    try {
      final permission = AppPermission.values.firstWhere(
        (p) => p.key == widget.requiredPermission,
        orElse: () => AppPermission.canManageProducts,
      );
      permissionDisplayName = permission.displayName;
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                'You do not have the required permission to view this content.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blueGrey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact your administrator if you believe you should have access to this feature.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.amber.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Required permission: $permissionDisplayName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}
