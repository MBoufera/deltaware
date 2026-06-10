import 'package:flutter/material.dart';
import '../../../../core/widgets/permission_guard.dart';

class ReturnsPage extends StatelessWidget {
  const ReturnsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: 'can_cancel_sales',
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        body: const Center(
          child: Text(
            'Returns & Refunds (Bon de Retour)',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
