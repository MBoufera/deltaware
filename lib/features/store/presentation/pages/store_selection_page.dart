import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/permissions_bloc.dart';
import '../../../../features/auth/presentation/bloc/permissions_event.dart';
import '../bloc/store_bloc.dart';
import '../bloc/store_event.dart';
import '../bloc/store_state.dart';
import '../../data/models/store_model.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({super.key});

  @override
  State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreBloc>().add(LoadUserStores());
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String get _userName {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@').first ??
        'User';
  }

  bool get _isSuperAdmin {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    return metadata['is_super_admin'] == true;
  }

  void _selectStore(Store store) {
    context.read<StoreBloc>().add(SelectStore(store));
    context.go('/dashboard');
  }

  void _logout() {
    context.read<PermissionsBloc>().add(ClearPermissions());
    context.read<StoreBloc>().add(ResetStore());
    context.read<AuthBloc>().add(LogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate900,
      body: BlocConsumer<StoreBloc, StoreState>(
        listener: (context, state) {
          if (state is StoreOperationSuccess) {
            // After create, select the new store and go to dashboard
            if (state.selectedStore != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _selectStore(state.selectedStore!);
              });
            } else {
              // Reload
              context.read<StoreBloc>().add(LoadUserStores());
            }
          } else if (state is StoresLoaded) {
            // Auto-select if only one store and NOT a super admin
            if (state.stores.length == 1 && state.selectedStore == null && !_isSuperAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _selectStore(state.stores.first);
              });
            }
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Ambient gradient blobs
              _buildBackground(),

              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _buildBody(state),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 400,
            height: 400,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.secondary,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / Brand
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deltaware',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                _isSuperAdmin ? 'Super Admin Portal' : 'Store Portal',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Logout
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF94A3B8)),
            label: const Text(
              'Sign out',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(StoreState state) {
    if (state is StoreLoading || state is StoreInitial) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading your stores...',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (state is StoreError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFF64748B), size: 48),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.read<StoreBloc>().add(LoadUserStores()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final stores = state is StoresLoaded ? state.stores : <Store>[];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                    children: [
                      const TextSpan(text: 'Welcome back,\n'),
                      TextSpan(
                        text: _userName,
                        style: TextStyle(
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [Color(0xFF60A5FA), Color(0xFFA78BFA)],
                            ).createShader(const Rect.fromLTWH(0, 0, 300, 60)),
                        ),
                      ),
                      const TextSpan(text: ' 👋'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  stores.isEmpty
                      ? 'No stores yet. Create your first store below.'
                      : 'Select a store to continue, or create a new one.',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 200,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == stores.length) {
                  // Create store card (super admin only)
                  if (!_isSuperAdmin) return null;
                  return _CreateStoreCard(
                    onTap: () => context.go('/store-select/create-store'),
                  );
                }
                return _StoreCard(
                  store: stores[index],
                  onTap: () => _selectStore(stores[index]),
                );
              },
              childCount: _isSuperAdmin ? stores.length + 1 : stores.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Store Card ────────────────────────────────────────────────────────────────

class _StoreCard extends StatefulWidget {
  final Store store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard> {
  bool _hovered = false;

  Color get _roleColor {
    switch (widget.store.myRole) {
      case 'super_admin':
        return AppColors.warning;
      case 'admin':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String get _roleLabel {
    switch (widget.store.myRole) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      default:
        return 'Worker';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF252D4A)
                : AppColors.slate800,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.slate700,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: -4,
                    )
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Store icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: _roleColor,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel,
                      style: TextStyle(
                        color: _roleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.store.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.store.subtitle.isNotEmpty ? widget.store.subtitle : ' ',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFF475569), size: 15),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.store.memberCount} members',
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                  ),
                  if (widget.store.address.isNotEmpty) ...[ 
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, color: Color(0xFF475569), size: 15),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.store.wilaya.isNotEmpty
                            ? widget.store.wilaya
                            : widget.store.address,
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Create Store Card ─────────────────────────────────────────────────────────

class _CreateStoreCard extends StatefulWidget {
  final VoidCallback onTap;
  const _CreateStoreCard({required this.onTap});

  @override
  State<_CreateStoreCard> createState() => _CreateStoreCardState();
}

class _CreateStoreCardState extends State<_CreateStoreCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: 0.7)
                  : AppColors.slate700,
              width: 2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.slate800,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: _hovered ? AppColors.primary : const Color(0xFF475569),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create New Store',
                  style: TextStyle(
                    color: _hovered ? AppColors.primary : const Color(0xFF64748B),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
