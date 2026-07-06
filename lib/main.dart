import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/bloc/permissions_bloc.dart';
import 'features/admin/presentation/bloc/role/role_bloc.dart';
import 'core/widgets/route_permission_guard.dart';
import 'features/admin/presentation/bloc/sales/sales_bloc.dart';
import 'features/admin/presentation/bloc/analytics/analytics_bloc.dart';
import 'features/store/presentation/bloc/store_bloc.dart';
import 'features/store/presentation/bloc/store_event.dart';
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
import 'features/admin/presentation/pages/audit_logs_page.dart';
import 'features/store/presentation/pages/store_selection_page.dart';
import 'features/store/presentation/pages/create_store_page.dart';
import 'features/admin/presentation/pages/programmer_console_page.dart';

import 'package:easy_localization/easy_localization.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
  }

  await Supabase.initialize(
    url: 'https://dggulctustnlfyadcanx.supabase.co',
    publishableKey: 'sb_publishable_4Axc_w_YA32cG_R9cZEIog_BrYh0RWR',
  );

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await windowManager.setMinimumSize(const Size(1024, 768));
      await windowManager.setSize(const Size(1280, 720));
      await windowManager.setResizable(true);
      await windowManager.center();
    } else {
      await windowManager.setMinimumSize(const Size(900, 600));
      await windowManager.setSize(const Size(900, 600));
      await windowManager.setResizable(false);
      await windowManager.center();
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _adminShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'admin_shell');

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loc = state.matchedLocation;
    final isGoingToLogin = loc == '/';
    final isGoingToStoreSelect =
        loc == '/store-select' || loc == '/store-select/create-store';
    final isGoingToProgrammer = loc == '/programmer';

    // Not logged in — boot to login
    if (session == null && !isGoingToLogin) return '/';

    // Already logged in — redirect away from login
    if (session != null && isGoingToLogin) {
      final metadata = session.user.userMetadata ?? {};
      final isProgrammer = metadata['is_programmer'] == true;
      if (isProgrammer) return '/programmer';
      final isSuperAdmin = metadata['is_super_admin'] == true;
      // Super admins always start at the store selector
      if (isSuperAdmin) return '/store-select';
      return '/dashboard';
    }

    // Protect Programmer route
    if (session != null && isGoingToProgrammer) {
      final metadata = session.user.userMetadata ?? {};
      final isProgrammer = metadata['is_programmer'] == true;
      if (!isProgrammer) return '/';
    }

    // Prevent non-super-admins from accessing store-select directly
    if (session != null && isGoingToStoreSelect) {
      // Multi-store non-super-admins are allowed (handled in AdminLayout)
      return null;
    }

    return null;
  },
  routes: [
    // ── Login ────────────────────────────────────────────────────────────
    GoRoute(path: '/', builder: (context, state) => const LoginPage()),

    // ── Programmer Dashboard / Console ────────────────────────────────────
    GoRoute(
      path: '/programmer',
      builder: (context, state) => const ProgrammerConsolePage(),
    ),

    // ── Store Selection (Super Admin & Multi-Store Users) ─────────────────
    GoRoute(
      path: '/store-select',
      builder: (context, state) => const StoreSelectionPage(),
      routes: [
        GoRoute(
          path: 'create-store',
          builder: (context, state) => const CreateStorePage(),
        ),
      ],
    ),

    // ── Admin Shell ───────────────────────────────────────────────────────
    ShellRoute(
      navigatorKey: _adminShellNavigatorKey,
      builder: (context, state, child) {
        return AdminLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => RoutePermissionGuard(
            route: '/dashboard',
            child: const AdminDashboardPage(),
          ),
          routes: [
            GoRoute(
              path: 'pos',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/pos',
                child: const PosPage(),
              ),
            ),
            GoRoute(
              path: 'suppliers',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/suppliers',
                child: const SuppliersPage(),
              ),
            ),
            GoRoute(
              path: 'expenses',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/expenses',
                child: const ExpensesPage(),
              ),
            ),
            GoRoute(
              path: 'returns',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/returns',
                child: const ReturnsPage(),
              ),
            ),
            GoRoute(
              path: 'analytics',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/analytics',
                child: const AnalyticsPage(),
              ),
            ),
            GoRoute(
              path: 'smart-batch',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/smart-batch',
                child: const SmartBatchPage(),
              ),
            ),
            GoRoute(
              path: 'stock',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/stock',
                child: const StockManagementPage(),
              ),
            ),
            GoRoute(
              path: 'categories',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/categories',
                child: const CategoryManagementPage(),
              ),
            ),
            GoRoute(
              path: 'products',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/products',
                child: const ProductsPage(),
              ),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) {
                    final product = state.extra as Map<String, dynamic>?;
                    return RoutePermissionGuard(
                      route: '/dashboard/products/add',
                      child: AddProductPage(product: product),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'users',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/users',
                child: const UserManagementPage(),
              ),
            ),
            GoRoute(
              path: 'roles',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/roles',
                child: const RoleManagementPage(),
              ),
            ),
            GoRoute(
              path: 'audit-logs',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/audit-logs',
                child: const AuditLogsPage(),
              ),
            ),
            GoRoute(
              path: 'documents',
              builder: (context, state) => RoutePermissionGuard(
                route: '/dashboard/documents',
                child: const DocumentHistoryPage(),
              ),
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()..add(AppStarted())),
        BlocProvider(create: (context) => PermissionsBloc()),
        BlocProvider(create: (context) => RoleBloc()),
        BlocProvider(create: (context) => SalesBloc(Supabase.instance.client)),
        BlocProvider(
          create: (context) => AnalyticsBloc(Supabase.instance.client),
          // NOTE: LoadDashboard is no longer fired here.
          // It is fired from AdminDashboardPage once the store context is known.
        ),
        BlocProvider(create: (context) => StoreBloc()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, authState) {
          if (authState is AuthUnauthenticated) {
            context.read<StoreBloc>().add(ResetStore());
            _router.go('/');
            if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
              windowManager.setResizable(false);
              windowManager.setMinimumSize(const Size(900, 600));
              windowManager.setSize(const Size(900, 600));
              windowManager.center();
            }
          } else if (authState is AuthAuthenticated || authState is AuthSuperAdmin) {
            if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
              windowManager.setResizable(true);
              windowManager.setMinimumSize(const Size(1024, 768));
              windowManager.setSize(const Size(1280, 720));
              windowManager.center();
            }
          }
        },
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
      ),
    );
  }
}
