import 'package:flutter/material.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../../../../core/widgets/permission_guard.dart';

class SuppliersPage extends StatelessWidget {
  const SuppliersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canManageClients.key,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        body: const Center(
          child: Text(
            'Suppliers Management (Fournisseurs)',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
