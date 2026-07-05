import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/core/services/permission_service.dart';
import 'permissions_event.dart';
import 'permissions_state.dart';

class PermissionsBloc extends Bloc<PermissionsEvent, PermissionsState> {
  final SupabaseClient _supabase;

  PermissionsBloc({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(PermissionsState()) {
    on<LoadPermissions>(_onLoadPermissions);
    on<RefreshPermissions>(_onRefreshPermissions);
    on<ClearPermissions>(_onClearPermissions);
  }

  // ─── Internal Logic ───────────────────────────────────────────────────────

  Future<PermissionsState> _buildState({
    required String userId,
    required String role,
    String? storeId,
    bool forceReload = false,
  }) async {
    // Check cache validity
    if (!forceReload &&
        !state.isCacheExpired() &&
        state.permissions.isNotEmpty &&
        state.lastLoadedAt != null) {
      return state; // Use cache
    }

    final currentUser = _supabase.auth.currentUser;
    final isSuperAdminUser = currentUser?.userMetadata?['is_super_admin'] == true;
    final userMetaRole = currentUser?.userMetadata?['role'] as String? ?? '';

    bool isSystemAdmin = role == 'admin' ||
        role == 'super_admin' ||
        userMetaRole == 'admin' ||
        userMetaRole == 'super_admin' ||
        isSuperAdminUser;

    // Verify admin status via DB roles (store-scoped if storeId provided)
    if (!isSystemAdmin) {
      try {
        final rolesQuery = _supabase
            .from('user_roles')
            .select('roles(name)')
            .eq('user_id', userId);

        final rolesResponse = await (storeId != null
            ? rolesQuery.eq('store_id', storeId)
            : rolesQuery);

        final rolesList = rolesResponse as List? ?? [];
        final hasAdminRole = rolesList.any((row) {
          final rolesMap = row['roles'];
          return rolesMap is Map && rolesMap['name'] == 'Admin';
        });
        if (hasAdminRole) isSystemAdmin = true;
      } catch (e) {
        debugPrint('Error checking admin roles: $e');
      }
    }

    // Verify admin status via store_members table
    if (!isSystemAdmin && storeId != null) {
      try {
        final memberResponse = await _supabase
            .from('store_members')
            .select('store_role')
            .eq('store_id', storeId)
            .eq('user_id', userId)
            .maybeSingle();
        if (memberResponse != null) {
          final storeRole = memberResponse['store_role'] as String?;
          if (storeRole == 'super_admin' || storeRole == 'admin') {
            isSystemAdmin = true;
          }
        }
      } catch (e) {
        debugPrint('Error checking store_members role: $e');
      }
    }

    if (isSystemAdmin) {
      return state.copyWith(
        isLoading: false,
        isAdmin: true,
        permissions: {},
        lastLoadedAt: DateTime.now(),
        userId: userId,
      );
    }

    try {
      final params = <String, dynamic>{'p_user_id': userId};
      if (storeId != null) params['p_store_id'] = storeId;

      final response = await _supabase.rpc('get_user_permissions', params: params);
      final permList = response as List? ?? [];
      final permsMap = <String, dynamic>{
        for (var k in permList) k as String: true
      };

      return state.copyWith(
        isLoading: false,
        isAdmin: false,
        permissions: permsMap,
        lastLoadedAt: DateTime.now(),
        userId: userId,
      );
    } catch (e) {
      return state.copyWith(
        isLoading: false,
        isAdmin: false,
        permissions: {},
        lastLoadedAt: DateTime.now(),
        userId: userId,
      );
    }
  }

  // ─── Handlers ─────────────────────────────────────────────────────────────

  Future<void> _onLoadPermissions(
    LoadPermissions event,
    Emitter<PermissionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, userId: event.userId));
    final next = await _buildState(
      userId: event.userId,
      role: event.role,
      storeId: event.storeId,
    );
    emit(next);
  }

  Future<void> _onRefreshPermissions(
    RefreshPermissions event,
    Emitter<PermissionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, userId: event.userId));
    final next = await _buildState(
      userId: event.userId,
      role: event.role,
      storeId: event.storeId,
      forceReload: true,
    );
    emit(next);
  }

  void _onClearPermissions(ClearPermissions event, Emitter<PermissionsState> emit) {
    if (state.userId != null) {
      try {
        permissionService.clearUserPermissions(state.userId!);
      } catch (_) {}
    }
    emit(PermissionsState());
  }
}
