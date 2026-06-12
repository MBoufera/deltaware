import 'package:equatable/equatable.dart';

abstract class RoleEvent extends Equatable {
  const RoleEvent();

  @override
  List<Object?> get props => [];
}

class LoadAllRoles extends RoleEvent {
  const LoadAllRoles();
}

class LoadUserRoles extends RoleEvent {
  final String userId;

  const LoadUserRoles(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LoadAllPermissions extends RoleEvent {
  const LoadAllPermissions();
}

class CreateRole extends RoleEvent {
  final String name;
  final String? description;
  final List<String> permissionKeys;

  const CreateRole({
    required this.name,
    this.description,
    required this.permissionKeys,
  });

  @override
  List<Object?> get props => [name, description, permissionKeys];
}

class UpdateRole extends RoleEvent {
  final String roleId;
  final String name;
  final String? description;
  final List<String> permissionKeys;

  const UpdateRole({
    required this.roleId,
    required this.name,
    this.description,
    required this.permissionKeys,
  });

  @override
  List<Object?> get props => [roleId, name, description, permissionKeys];
}

class DeleteRole extends RoleEvent {
  final String roleId;

  const DeleteRole(this.roleId);

  @override
  List<Object?> get props => [roleId];
}

class AssignRoleToUser extends RoleEvent {
  final String userId;
  final String roleId;

  const AssignRoleToUser({
    required this.userId,
    required this.roleId,
  });

  @override
  List<Object?> get props => [userId, roleId];
}

class RemoveRoleFromUser extends RoleEvent {
  final String userId;
  final String roleId;

  const RemoveRoleFromUser({
    required this.userId,
    required this.roleId,
  });

  @override
  List<Object?> get props => [userId, roleId];
}

class ClearRoleError extends RoleEvent {
  const ClearRoleError();
}

/// Atomically syncs a user's roles: assigns newly added ones and removes
/// ones that were unchecked. Prevents race conditions from N separate events.
class SyncUserRoles extends RoleEvent {
  final String userId;
  final List<String> rolesToAdd;
  final List<String> rolesToRemove;

  const SyncUserRoles({
    required this.userId,
    required this.rolesToAdd,
    required this.rolesToRemove,
  });

  @override
  List<Object?> get props => [userId, rolesToAdd, rolesToRemove];
}
