import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class WorkerLayout extends StatelessWidget {
  final Widget child;

  const WorkerLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('worker.dashboard'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF203A43),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'logout'.tr(),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
              context.go('/');
            },
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF203A43),
        unselectedItemColor: Colors.grey,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: 'dashboard'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.point_of_sale),
            label: 'pos'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2),
            label: 'products'.tr(),
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/worker-dashboard/pos')) return 1;
    if (location.startsWith('/worker-dashboard/products')) return 2;
    return 0; // Default to Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/worker-dashboard');
        break;
      case 1:
        context.go('/worker-dashboard/pos');
        break;
      case 2:
        context.go('/worker-dashboard/products');
        break;
    }
  }
}
