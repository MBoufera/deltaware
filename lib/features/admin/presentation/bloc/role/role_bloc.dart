import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/role_model.dart';
import '../../../data/services/role_service.dart';
import 'role_event.dart';
import 'role_state.dart';

class RoleBloc extends Bloc<RoleEvent, RoleState> {
  final RoleService roleService;

  RoleBloc({RoleService? roleService})
      : roleService = roleService ?? RoleService(),
        super(const RoleState()) {
    on<LoadAllRoles>(_onLoadAllRoles);
    on<LoadUserRoles>(_onLoadUserRoles);
    on<LoadAllPermissions>(_onLoadAllPermissions);
    on<CreateRole>(_onCreateRole);
    on<UpdateRole>(_onUpdateRole);
    on<DeleteRole>(_onDeleteRole);
    on<AssignRoleToUser>(_onAssignRoleToUser);
    on<RemoveRoleFromUser>(_onRemoveRoleFromUser);
    on<SyncUserRoles>(_onSyncUserRoles);
    on<ClearRoleError>(_onClearRoleError);
  }

  Future<void> _onLoadAllRoles(LoadAllRoles event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final roles = await roleService.listAllRoles();
      emit(state.copyWith(
        isLoading: false,
        roles: roles,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load roles: $e',
      ));
    }
  }

  Future<void> _onLoadUserRoles(LoadUserRoles event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final userRoles = await roleService.getUserRoles(event.userId);
      emit(state.copyWith(
        isLoading: false,
        userRoles: userRoles,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load user roles: $e',
      ));
    }
  }

  Future<void> _onLoadAllPermissions(LoadAllPermissions event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final permissions = await roleService.listAllPermissions();
      emit(state.copyWith(
        isLoading: false,
        permissions: permissions,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load permissions: $e',
      ));
    }
  }

  Future<void> _onCreateRole(CreateRole event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await roleService.createRole(
        name: event.name,
        description: event.description,
        permissionKeys: event.permissionKeys,
      );

      // Refresh the roles list
      final roles = await roleService.listAllRoles();
      emit(state.copyWith(
        isLoading: false,
        roles: roles,
        successMessage: 'Role created successfully',
        isSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to create role: $e',
      ));
    }
  }

  Future<void> _onUpdateRole(UpdateRole event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await roleService.updateRole(
        roleId: event.roleId,
        name: event.name,
        description: event.description,
        permissionKeys: event.permissionKeys,
      );

      // Refresh the roles list
      final roles = await roleService.listAllRoles();
      emit(state.copyWith(
        isLoading: false,
        roles: roles,
        successMessage: 'Role updated successfully',
        isSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to update role: $e',
      ));
    }
  }

  Future<void> _onDeleteRole(DeleteRole event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await roleService.deleteRole(event.roleId);

      // Refresh the roles list
      final roles = await roleService.listAllRoles();
      emit(state.copyWith(
        isLoading: false,
        roles: roles,
        successMessage: 'Role deleted successfully',
        isSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to delete role: $e',
      ));
    }
  }

  Future<void> _onAssignRoleToUser(AssignRoleToUser event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await roleService.assignRoleToUser(event.userId, event.roleId);

      // Refresh user roles if they're loaded
      UserRoleAssignment? updatedUserRoles;
      if (state.userRoles?.userId == event.userId) {
        updatedUserRoles = await roleService.getUserRoles(event.userId);
      }

      emit(state.copyWith(
        isLoading: false,
        userRoles: updatedUserRoles ?? state.userRoles,
        successMessage: 'Role assigned successfully',
        isSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to assign role: $e',
      ));
    }
  }

  Future<void> _onRemoveRoleFromUser(RemoveRoleFromUser event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await roleService.removeRoleFromUser(event.userId, event.roleId);

      // Refresh user roles if they're loaded
      UserRoleAssignment? updatedUserRoles;
      if (state.userRoles?.userId == event.userId) {
        updatedUserRoles = await roleService.getUserRoles(event.userId);
      }

      emit(state.copyWith(
        isLoading: false,
        userRoles: updatedUserRoles ?? state.userRoles,
        successMessage: 'Role removed successfully',
        isSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to remove role: $e',
      ));
    }
  }

  void _onClearRoleError(ClearRoleError event, Emitter<RoleState> emit) {
    emit(state.copyWith(
      error: null,
      successMessage: null,
      isSuccess: false,
    ));
  }

  /// Handles all role assignment changes atomically in a single BLoC event.
  /// Runs assign and remove calls sequentially, then does one final refresh.
  Future<void> _onSyncUserRoles(SyncUserRoles event, Emitter<RoleState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      // Run all removals first
      for (final roleId in event.rolesToRemove) {
        await roleService.removeRoleFromUser(event.userId, roleId);
      }
      // Then all additions
      for (final roleId in event.rolesToAdd) {
        await roleService.assignRoleToUser(event.userId, roleId);
      }
      // Single refresh after all changes are done
      final updatedUserRoles = await roleService.getUserRoles(event.userId);
      emit(state.copyWith(
        isLoading: false,
        userRoles: updatedUserRoles,
        successMessage: 'Roles updated successfully',
        isSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to sync roles: $e',
      ));
    }
  }
}
