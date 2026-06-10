import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/permissions_bloc.dart';
import 'features/admin/presentation/bloc/sales/sales_bloc.dart';
import 'features/admin/presentation/bloc/analytics/analytics_bloc.dart';
import 'features/admin/presentation/bloc/analytics/analytics_event.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/admin/presentation/pages/admin_dashboard_page.dart';
import 'features/admin/presentation/pages/user_management_page.dart';
import 'features/admin/presentation/pages/role_management_page.dart';
import 'features/admin/presentation/pages/admin_layout.dart';
import 'features/admin/presentation/pages/smart_batch_page.dart';
import 'features/admin/presentation/pages/products_page.dart';
import 'features/admin/presentation/pages/add_product_page.dart';
import 'features/admin/presentation/pages/stock_management_page.dart';
import 'features/admin/presentation/pages/category_management_page.dart';
import 'features/admin/presentation/pages/pos_page.dart';
import 'features/admin/presentation/pages/suppliers_page.dart';
import 'features/admin/presentation/pages/expenses_page.dart';
import 'features/admin/presentation/pages/returns_page.dart';
import 'features/admin/presentation/pages/analytics_page.dart';
import 'features/admin/presentation/pages/document_history_page.dart';

import 'package:easy_localization/easy_localization.dart';

import 'core/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://dggulctustnlfyadcanx.supabase.co',
    publishableKey: 'sb_publishable_4Axc_w_YA32cG_R9cZEIog_BrYh0RWR',
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
final GlobalKey<NavigatorState> _adminShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'admin_shell');
final GlobalKey<NavigatorState> _workerShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'worker_shell');

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isGoingToLogin = state.matchedLocation == '/';
    
    if (session != null && isGoingToLogin) {
      return '/dashboard';
    }
    
    if (session == null && !isGoingToLogin) {
      return '/';
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      navigatorKey: _adminShellNavigatorKey,
      builder: (context, state, child) {
        return AdminLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const AdminDashboardPage(),
          routes: [
            GoRoute(path: 'pos', builder: (context, state) => const PosPage()),
            GoRoute(path: 'suppliers', builder: (context, state) => const SuppliersPage()),
            GoRoute(path: 'expenses', builder: (context, state) => const ExpensesPage()),
            GoRoute(path: 'returns', builder: (context, state) => const ReturnsPage()),
            GoRoute(path: 'analytics', builder: (context, state) => const AnalyticsPage()),
            GoRoute(path: 'smart-batch', builder: (context, state) => const SmartBatchPage()),
            GoRoute(path: 'stock', builder: (context, state) => const StockManagementPage()),
            GoRoute(path: 'categories', builder: (context, state) => const CategoryManagementPage()),
            GoRoute(
              path: 'products',
              builder: (context, state) => const ProductsPage(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) {
                    final product = state.extra as Map<String, dynamic>?;
                    return AddProductPage(product: product);
                  },
                ),
              ],
            ),
            GoRoute(path: 'users', builder: (context, state) => const UserManagementPage()),
            GoRoute(path: 'roles', builder: (context, state) => const RoleManagementPage()),
            GoRoute(path: 'documents', builder: (context, state) => const DocumentHistoryPage()),
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()..add(AppStarted())),
        BlocProvider(create: (context) => PermissionsBloc()),
        BlocProvider(create: (context) => SalesBloc(Supabase.instance.client)),
        BlocProvider(create: (context) => AnalyticsBloc(Supabase.instance.client)..add(const LoadDashboard())),
      ],
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

