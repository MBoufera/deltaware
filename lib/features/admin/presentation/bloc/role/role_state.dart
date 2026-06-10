import 'package:equatable/equatable.dart';
import '../../../data/models/role_model.dart';

class RoleState extends Equatable {
  final bool isLoading;
  final List<Role> roles;
  final Map<String, List<AppPermission>> permissions; // grouped by category
  final UserRoleAssignment? userRoles;
  final String? error;
  final String? successMessage;
  final bool isSuccess;

  const RoleState({
    this.isLoading = false,
    this.roles = const [],
    this.permissions = const {},
    this.userRoles,
    this.error,
    this.successMessage,
    this.isSuccess = false,
  });

  RoleState copyWith({
    bool? isLoading,
    List<Role>? roles,
    Map<String, List<AppPermission>>? permissions,
    UserRoleAssignment? userRoles,
    String? error,
    String? successMessage,
    bool? isSuccess,
  }) {
    return RoleState(
      isLoading: isLoading ?? this.isLoading,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      userRoles: userRoles ?? this.userRoles,
      error: error,
      successMessage: successMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    roles,
    permissions,
    userRoles,
    error,
    successMessage,
    isSuccess,
  ];
}
