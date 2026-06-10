class PermissionsState {
  final bool isLoading;
  final bool isAdmin;
  final Map<String, dynamic> permissions;

  PermissionsState({
    this.isLoading = true,
    this.isAdmin = false,
    this.permissions = const {},
  });

  bool hasPermission(String key) {
    if (isAdmin) return true;
    return permissions[key] == true;
  }

  PermissionsState copyWith({
    bool? isLoading,
    bool? isAdmin,
    Map<String, dynamic>? permissions,
  }) {
    return PermissionsState(
      isLoading: isLoading ?? this.isLoading,
      isAdmin: isAdmin ?? this.isAdmin,
      permissions: permissions ?? this.permissions,
    );
  }
}
