import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/permissions_bloc.dart';
import '../../../auth/presentation/bloc/permissions_event.dart';
import '../../../auth/presentation/bloc/permissions_state.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../../features/store/presentation/bloc/store_event.dart';
import '../../../../features/store/presentation/bloc/store_state.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return MultiBlocListener(
      listeners: [
        BlocListener<StoreBloc, StoreState>(
          // When a multi-store non-super-admin logs in with no store selected,
          // push them to the store picker.
          listenWhen: (prev, curr) => curr is StoresLoaded,
          listener: (context, state) {
            final isSuperAdmin = Supabase.instance.client.auth.currentUser
                    ?.userMetadata?['is_super_admin'] == true;
            if (state is StoresLoaded && state.needsStoreSelection) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/store-select');
              });
            } else if (state is StoresLoaded && state.isSingleStore && state.selectedStore == null && !isSuperAdmin) {
              // Auto-select the only store (exclude super admin)
              context.read<StoreBloc>().add(SelectStore(state.stores.first));
            }
          },
        ),
        BlocListener<StoreBloc, StoreState>(
          listenWhen: (prev, curr) {
            final prevId = prev is StoresLoaded ? prev.selectedStore?.id : null;
            final currId = curr is StoresLoaded ? curr.selectedStore?.id : null;
            return prevId != currId;
          },
          listener: (context, state) {
            if (state is StoresLoaded && state.selectedStore != null) {
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                final role = user.userMetadata?['role'] as String? ?? '';
                context.read<PermissionsBloc>().add(
                      RefreshPermissions(user.id, role, storeId: state.selectedStore!.id),
                    );
              }
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        drawer: isDesktop ? null : const _AdminSidebar(isDrawer: true),
        appBar: isDesktop
            ? null
            : AppBar(
                backgroundColor: const Color(0xFF1A2A32),
                foregroundColor: Colors.white,
                elevation: 0,
                title: const Text('Deltaware',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
        body: Row(
          children: [
            if (isDesktop) const _AdminSidebar(isDrawer: false),
            Expanded(
              child: ClipRRect(
                borderRadius: isDesktop
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        bottomLeft: Radius.circular(30))
                    : BorderRadius.zero,
                child: Container(
                  color: const Color(0xFFF4F7F6),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSidebar extends StatefulWidget {
  final bool isDrawer;
  const _AdminSidebar({required this.isDrawer});

  @override
  State<_AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<_AdminSidebar> {
  String _userInitial = 'U';
  String _userName = 'User';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserAndDispatchPermissions();
  }

  void _loadUserAndDispatchPermissions() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final user = session.user;
      final role = user.userMetadata?['role'] as String? ?? '';
      final name = user.userMetadata?['full_name'] as String? ?? 'User';

      setState(() {
        _userName = name;
        _userEmail = user.email ?? '';
        _userInitial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
      });

      // Load stores for this user
      final storeBloc = context.read<StoreBloc>();
      if (storeBloc.state is StoreInitial) {
        storeBloc.add(LoadUserStores());
      }

      // Load permissions scoped to the active store
      final storeId = storeBloc.currentStoreId;
      final permissionsBloc = context.read<PermissionsBloc>();
      final currentState = permissionsBloc.state;

      if (currentState.lastLoadedAt == null || currentState.isCacheExpired()) {
        permissionsBloc.add(LoadPermissions(user.id, role, storeId: storeId));
      }
    }
  }

  void _toggleLanguage(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    if (currentLocale == 'en') {
      context.setLocale(const Locale('fr'));
    } else if (currentLocale == 'fr') {
      context.setLocale(const Locale('ar'));
    } else {
      context.setLocale(const Locale('en'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    final sidebarContent = Container(
      width: 260,
      color: const Color(0xFF1A2A32),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Logo Area + Store Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: BlocBuilder<StoreBloc, StoreState>(
              builder: (context, storeState) {
                final storeName = storeState is StoresLoaded
                    ? storeState.selectedStore?.name
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dashboard_customize,
                            color: Colors.blue.shade300, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Deltaware',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    if (storeName != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_rounded,
                                color: Colors.blue, size: 12),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                storeName,
                                style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          
          // Navigation Links
          Expanded(
            child: BlocBuilder<StoreBloc, StoreState>(
              builder: (context, storeState) {
                final isSuperAdmin = Supabase.instance.client.auth.currentUser
                        ?.userMetadata?['is_super_admin'] ==
                    true;
                final isMultiStore = storeState is StoresLoaded &&
                    storeState.stores.length > 1;
                final canSwitchStore = isSuperAdmin || isMultiStore;

                return BlocBuilder<PermissionsBloc, PermissionsState>(
                  builder: (context, permissionsState) {
                    if (permissionsState.isLoading) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white54));
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // ── Switch Store (super admin / multi-store) ──────
                        if (canSwitchStore) ...[
                          _SidebarItem(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Switch Store',
                            isActive: false,
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context
                                  .read<StoreBloc>()
                                  .add(ClearSelectedStore());
                              context.go('/store-select');
                            },
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.08),
                                height: 1),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // ── Dashboard Overview ─────────────────────────────
                        if (permissionsState
                            .hasPermission(AppPermission.canViewReports.key)) ...[
                          _SidebarItem(
                            icon: Icons.pie_chart_outline,
                            label: 'sidebar.overview'.tr(),
                            isActive: location == '/dashboard',
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard');
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── POS ────────────────────────────────────────────
                        _SidebarItem(
                          icon: Icons.point_of_sale,
                          label: 'sidebar.pos'.tr(),
                          isActive: location.startsWith('/dashboard/pos'),
                          onTap: () {
                            if (widget.isDrawer) Navigator.pop(context);
                            context.go('/dashboard/pos');
                          },
                        ),
                        const SizedBox(height: 8),

                        // ── Inventory ──────────────────────────────────────
                        if (permissionsState.hasPermission(
                            AppPermission.canManageProducts.key)) ...[
                          _SidebarItem(
                            icon: Icons.inventory_2_outlined,
                            label: 'sidebar.inventory'.tr(),
                            isActive:
                                location.startsWith('/dashboard/products'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/products');
                            },
                          ),
                          const SizedBox(height: 8),
                          _SidebarItem(
                            icon: Icons.document_scanner_outlined,
                            label: 'sidebar.smart_invoice'.tr(),
                            isActive: location
                                .startsWith('/dashboard/smart-batch'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/smart-batch');
                            },
                          ),
                          const SizedBox(height: 8),
                          _SidebarItem(
                            icon: Icons.category_outlined,
                            label: 'Categories',
                            isActive:
                                location.startsWith('/dashboard/categories'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/categories');
                            },
                          ),
                          const SizedBox(height: 8),
                          _SidebarItem(
                            icon: Icons.storage_outlined,
                            label: 'Stock',
                            isActive:
                                location.startsWith('/dashboard/stock'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/stock');
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── Document History ───────────────────────────────
                        if (permissionsState.hasPermission(
                            AppPermission.canViewAllSales.key)) ...[
                          _SidebarItem(
                            icon: Icons.history_edu,
                            label: 'Historique',
                            isActive:
                                location.startsWith('/dashboard/documents'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/documents');
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── Suppliers ──────────────────────────────────────
                        if (permissionsState.hasPermission(
                            AppPermission.canManageClients.key)) ...[
                          _SidebarItem(
                            icon: Icons.local_shipping_outlined,
                            label: 'sidebar.suppliers'.tr(),
                            isActive:
                                location.startsWith('/dashboard/suppliers'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/suppliers');
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── Expenses ───────────────────────────────────────
                        if (permissionsState.hasPermission(
                            AppPermission.canManageSettings.key)) ...[
                          _SidebarItem(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'sidebar.expenses'.tr(),
                            isActive:
                                location.startsWith('/dashboard/expenses'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/expenses');
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── Returns ────────────────────────────────────────
                        if (permissionsState.hasPermission(
                            AppPermission.canCancelSales.key)) ...[
                          _SidebarItem(
                            icon: Icons.keyboard_return_outlined,
                            label: 'sidebar.returns'.tr(),
                            isActive:
                                location.startsWith('/dashboard/returns'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/returns');
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── Analytics ──────────────────────────────────────
                        if (permissionsState.hasPermission(
                            AppPermission.canViewReports.key)) ...[
                          _SidebarItem(
                            icon: Icons.bar_chart_outlined,
                            label: 'sidebar.analytics'.tr(),
                            isActive:
                                location.startsWith('/dashboard/analytics'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/analytics');
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── Admin-only ─────────────────────────────────────
                        if (permissionsState.isAdmin) ...[
                          _SidebarItem(
                            icon: Icons.people_outline,
                            label: 'sidebar.users'.tr(),
                            isActive:
                                location.startsWith('/dashboard/users'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/users');
                            },
                          ),
                          const SizedBox(height: 8),
                          _SidebarItem(
                            icon: Icons.security_outlined,
                            label: 'sidebar.roles'.tr(),
                            isActive:
                                location.startsWith('/dashboard/roles'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/roles');
                            },
                          ),
                          const SizedBox(height: 8),
                          _SidebarItem(
                            icon: Icons.history_outlined,
                            label: 'Audit Logs',
                            isActive:
                                location.startsWith('/dashboard/audit-logs'),
                            onTap: () {
                              if (widget.isDrawer) Navigator.pop(context);
                              context.go('/dashboard/audit-logs');
                            },
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // Bottom User Profile & Language Switcher
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _toggleLanguage(context),
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${'sidebar.language'.tr()} (${context.locale.languageCode.toUpperCase()})',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    BlocBuilder<PermissionsBloc, PermissionsState>(
                      builder: (context, permissionsState) {
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: permissionsState.isAdmin ? Colors.blue.shade900 : Colors.teal.shade700,
                          child: Text(_userInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        );
                      }
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _userEmail,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                      onPressed: () {
                        context.read<PermissionsBloc>().add(ClearPermissions());
                        context.read<StoreBloc>().add(ResetStore());
                        context.read<AuthBloc>().add(LogoutRequested());
                      },
                      tooltip: 'sidebar.logout'.tr(),
                    )
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );

    return widget.isDrawer ? Drawer(child: sidebarContent) : sidebarContent;
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? Colors.white : (_isHovered ? Colors.white : Colors.white60);
    final bgColor = widget.isActive 
        ? Colors.blue.withValues(alpha: 0.15) 
        : (_isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: widget.isActive 
                ? Border.all(color: Colors.blue.withValues(alpha: 0.3)) 
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
