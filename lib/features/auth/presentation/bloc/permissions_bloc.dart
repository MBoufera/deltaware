import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/core/services/permission_service.dart';
import 'permissions_event.dart';
import 'permissions_state.dart';

class PermissionsBloc extends Bloc<PermissionsEvent, PermissionsState> {
  PermissionsBloc() : super(PermissionsState()) {
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
    
    if (event.role == 'admin') {
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
      // Load permissions from user's roles
      final response = await Supabase.instance.client.rpc(
        'get_user_permissions',
        params: {'p_user_id': event.userId},
      );

      if (response != null) {
        // Convert list of permission keys to a map for compatibility
        final permissionsList = response as List?;
        final permissionsMap = <String, dynamic>{};
        
        if (permissionsList != null) {
          for (var permKey in permissionsList) {
            permissionsMap[permKey as String] = true;
          }
        }

        emit(state.copyWith(
          isLoading: false,
          isAdmin: false,
          permissions: permissionsMap,
          lastLoadedAt: DateTime.now(),
          userId: event.userId,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          isAdmin: false,
          permissions: {},
          lastLoadedAt: DateTime.now(),
          userId: event.userId,
        ));
      }
    } catch (e) {
      // Fallback to checking old user_permissions table for backwards compatibility
      try {
        final legacyResponse = await Supabase.instance.client
            .from('user_permissions')
            .select()
            .eq('user_id', event.userId)
            .maybeSingle();

        if (legacyResponse != null) {
          emit(state.copyWith(
            isLoading: false,
            isAdmin: false,
            permissions: legacyResponse,
            lastLoadedAt: DateTime.now(),
          ));
        } else {
          emit(state.copyWith(
            isLoading: false,
            isAdmin: false,
            permissions: {},
            lastLoadedAt: DateTime.now(),
          ));
        }
      } catch (_) {
        emit(state.copyWith(
          isLoading: false,
          isAdmin: false,
          permissions: {},
          lastLoadedAt: DateTime.now(),
        ));
      }
    }
  }

  Future<void> _onRefreshPermissions(RefreshPermissions event, Emitter<PermissionsState> emit) async {
    // Force reload permissions, bypassing cache
    emit(state.copyWith(isLoading: true, userId: event.userId));
    
    if (event.role == 'admin') {
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
      final response = await Supabase.instance.client.rpc(
        'get_user_permissions',
        params: {'p_user_id': event.userId},
      );

      if (response != null) {
        final permissionsList = response as List?;
        final permissionsMap = <String, dynamic>{};
        
        if (permissionsList != null) {
          for (var permKey in permissionsList) {
            permissionsMap[permKey as String] = true;
          }
        }

        emit(state.copyWith(
          isLoading: false,
          isAdmin: false,
          permissions: permissionsMap,
          lastLoadedAt: DateTime.now(),
          userId: event.userId,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          isAdmin: false,
          permissions: {},
          lastLoadedAt: DateTime.now(),
          userId: event.userId,
        ));
      }
    } catch (e) {
      try {
        final legacyResponse = await Supabase.instance.client
            .from('user_permissions')
            .select()
            .eq('user_id', event.userId)
            .maybeSingle();

        if (legacyResponse != null) {
          emit(state.copyWith(
            isLoading: false,
            isAdmin: false,
            permissions: legacyResponse,
            lastLoadedAt: DateTime.now(),
            userId: event.userId,
          ));
        } else {
          emit(state.copyWith(
            isLoading: false,
            isAdmin: false,
            permissions: {},
            lastLoadedAt: DateTime.now(),
            userId: event.userId,
          ));
        }
      } catch (_) {
        emit(state.copyWith(
          isLoading: false,
          isAdmin: false,
          permissions: {},
          lastLoadedAt: DateTime.now(),
          userId: event.userId,
        ));
      }
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
