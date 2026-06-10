abstract class PermissionsEvent {}

class LoadPermissions extends PermissionsEvent {
  final String userId;
  final String role;
  
  LoadPermissions(this.userId, this.role);
}

class ClearPermissions extends PermissionsEvent {}
