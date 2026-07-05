abstract class PermissionsEvent {}

class LoadPermissions extends PermissionsEvent {
  final String userId;
  final String role;
  final String? storeId; // null = no store context (super admin global view)

  LoadPermissions(this.userId, this.role, {this.storeId});
}

class RefreshPermissions extends PermissionsEvent {
  final String userId;
  final String role;
  final String? storeId;

  RefreshPermissions(this.userId, this.role, {this.storeId});
}

class ClearPermissions extends PermissionsEvent {}
