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

  Future<void> _onLoadPermissions(LoadPermissions event, Emitter<PermissionsState> emit) async {
    // Check if we have valid cached permissions
    if (!state.isCacheExpired() && state.permissions.isNotEmpty && state.lastLoadedAt != null) {
      return; // Use cached permissions
    }

    emit(state.copyWith(isLoading: true, userId: event.userId));

    bool isSystemAdmin = event.role == 'admin';

    // Double check with DB roles
    try {
      final rolesResponse = await _supabase
          .from('user_roles')
          .select('roles(name)')
          .eq('user_id', event.userId);
      
      final rolesList = rolesResponse as List? ?? [];
      final hasAdminRole = rolesList.any((row) {
        final rolesMap = row['roles'];
        return rolesMap is Map && rolesMap['name'] == 'Admin';
      });
      if (hasAdminRole) {
        isSystemAdmin = true;
      }
    } catch (e) {
      // Silently fall back to metadata role if query fails
      debugPrint('Error fetching user roles for admin check: $e');
    }

    if (isSystemAdmin) {
      emit(state.copyWith(
        isLoading: false,
        isAdmin: true,
        permissions: {},
        lastLoadedAt: DateTime.now(),
        userId: event.userId,
      ));
      return;
    }

    try {
      // Load permissions from user's RBAC roles
      final response = await _supabase.rpc(
        'get_user_permissions',
        params: {'p_user_id': event.userId},
      );

      final permissionsList = response as List? ?? [];
      final permissionsMap = <String, dynamic>{};
      for (var permKey in permissionsList) {
        permissionsMap[permKey as String] = true;
      }

      emit(state.copyWith(
        isLoading: false,
        isAdmin: false,
        permissions: permissionsMap,
        lastLoadedAt: DateTime.now(),
        userId: event.userId,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isAdmin: false,
        permissions: {},
        lastLoadedAt: DateTime.now(),
        userId: event.userId,
      ));
    }
  }

  Future<void> _onRefreshPermissions(RefreshPermissions event, Emitter<PermissionsState> emit) async {
    // Force reload permissions, bypassing cache
    emit(state.copyWith(isLoading: true, userId: event.userId));

    bool isSystemAdmin = event.role == 'admin';

    // Double check with DB roles
    try {
      final rolesResponse = await _supabase
          .from('user_roles')
          .select('roles(name)')
          .eq('user_id', event.userId);
      
      final rolesList = rolesResponse as List? ?? [];
      final hasAdminRole = rolesList.any((row) {
        final rolesMap = row['roles'];
        return rolesMap is Map && rolesMap['name'] == 'Admin';
      });
      if (hasAdminRole) {
        isSystemAdmin = true;
      }
    } catch (e) {
      // Silently fall back to metadata role if query fails
      debugPrint('Error fetching user roles for admin check: $e');
    }

    if (isSystemAdmin) {
      emit(state.copyWith(
        isLoading: false,
        isAdmin: true,
        permissions: {},
        lastLoadedAt: DateTime.now(),
        userId: event.userId,
      ));
      return;
    }

    try {
      final response = await _supabase.rpc(
        'get_user_permissions',
        params: {'p_user_id': event.userId},
      );

      final permissionsList = response as List? ?? [];
      final permissionsMap = <String, dynamic>{};
      for (var permKey in permissionsList) {
        permissionsMap[permKey as String] = true;
      }

      emit(state.copyWith(
        isLoading: false,
        isAdmin: false,
        permissions: permissionsMap,
        lastLoadedAt: DateTime.now(),
        userId: event.userId,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isAdmin: false,
        permissions: {},
        lastLoadedAt: DateTime.now(),
        userId: event.userId,
      ));
    }
  }

  void _onClearPermissions(ClearPermissions event, Emitter<PermissionsState> emit) {
    // Clear extended permissions if userId available
    if (state.userId != null) {
      try {
        permissionService.clearUserPermissions(state.userId!);
      } catch (_) {}
    }
    emit(PermissionsState()); // reset to default loading state
  }
}
