import 'package:flutter/material.dart';
import '../../../../core/widgets/permission_guard.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: 'can_manage_settings',
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        body: const Center(
          child: Text(
            'Expenses & Cash Flow (Les Charges)',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
