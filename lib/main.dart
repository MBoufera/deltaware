import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/admin/presentation/pages/admin_dashboard_page.dart';
import 'features/admin/presentation/pages/user_management_page.dart';
import 'features/admin/presentation/pages/role_management_page.dart';
import 'features/admin/presentation/pages/admin_layout.dart';
import 'features/admin/presentation/pages/smart_batch_page.dart';
import 'features/admin/presentation/pages/products_page.dart';
import 'features/admin/presentation/pages/add_product_page.dart';
import 'features/admin/presentation/pages/pos_page.dart';
import 'features/admin/presentation/pages/suppliers_page.dart';
import 'features/admin/presentation/pages/expenses_page.dart';
import 'features/admin/presentation/pages/returns_page.dart';
import 'features/admin/presentation/pages/analytics_page.dart';

import 'package:easy_localization/easy_localization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://dggulctustnlfyadcanx.supabase.co',
    anonKey: 'sb_publishable_4Axc_w_YA32cG_R9cZEIog_BrYh0RWR',
  );
  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AdminLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/admin-dashboard',
          builder: (context, state) => const AdminDashboardPage(),
          routes: [
            GoRoute(
              path: 'pos',
              builder: (context, state) => const PosPage(),
            ),
            GoRoute(
              path: 'suppliers',
              builder: (context, state) => const SuppliersPage(),
            ),
            GoRoute(
              path: 'expenses',
              builder: (context, state) => const ExpensesPage(),
            ),
            GoRoute(
              path: 'returns',
              builder: (context, state) => const ReturnsPage(),
            ),
            GoRoute(
              path: 'analytics',
              builder: (context, state) => const AnalyticsPage(),
            ),
            GoRoute(
              path: 'smart-batch',
              builder: (context, state) => const SmartBatchPage(),
            ),
            GoRoute(
              path: 'products',
              builder: (context, state) => const ProductsPage(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const AddProductPage(),
                ),
              ],
            ),
            GoRoute(
              path: 'users',
              builder: (context, state) => const UserManagementPage(),
            ),
            GoRoute(
              path: 'roles',
              builder: (context, state) => const RoleManagementPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: MaterialApp.router(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        title: 'Deltaware',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF203A43)),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        backgroundColor: const Color(0xFF203A43),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Welcome to Deltaware Staff Dashboard!'),
      ),
    );
  }
}
