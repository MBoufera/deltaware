import 'package:equatable/equatable.dart';

/// Represents a permission in the system
class AppPermission extends Equatable {
  final String id;
  final String key;
  final String name;
  final String? description;
  final String category;
  final DateTime createdAt;

  const AppPermission({
    required this.id,
    required this.key,
    required this.name,
    this.description,
    required this.category,
    required this.createdAt,
  });

  factory AppPermission.fromJson(Map<String, dynamic> json) {
    return AppPermission(
      id: json['id'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'general',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'name': name,
      'description': description,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, key, name, description, category, createdAt];
}

/// Represents a role in the system
class Role extends Equatable {
  final String id;
  final String name;
  final String? description;
  final bool isSystem;
  final List<AppPermission> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const Role({
    required this.id,
    required this.name,
    this.description,
    required this.isSystem,
    this.permissions = const [],
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Get all permission keys for this role
  List<String> getPermissionKeys() {
    return permissions.map((p) => p.key).toList();
  }

  /// Check if role has a specific permission
  bool hasPermission(String permissionKey) {
    return permissions.any((p) => p.key == permissionKey);
  }

  /// Get permissions grouped by category
  Map<String, List<AppPermission>> getPermissionsByCategory() {
    final grouped = <String, List<AppPermission>>{};
    for (var permission in permissions) {
      grouped.putIfAbsent(permission.category, () => []).add(permission);
    }
    return grouped;
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    final permList = json['permissions'] as List? ?? [];
    return Role(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      permissions: List<AppPermission>.from(
        permList.map((p) => AppPermission.fromJson(p as Map<String, dynamic>)),
      ),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : json['created_at'] != null 
              ? DateTime.parse(json['created_at'] as String) 
              : DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_system': isSystem,
      'permissions': permissions.map((p) => p.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Create a copy with modified fields
  Role copyWith({
    String? id,
    String? name,
    String? description,
    bool? isSystem,
    List<AppPermission>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isSystem: isSystem ?? this.isSystem,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  List<Object?> get props => [id, name, description, isSystem, permissions, createdAt, updatedAt, createdBy];
}

/// Represents user roles with their permissions
class UserRoleAssignment extends Equatable {
  final String userId;
  final List<Role> roles;

  const UserRoleAssignment({
    required this.userId,
    required this.roles,
  });

  /// Get all permissions from all roles
  List<String> getAllPermissionKeys() {
    final permissions = <String>{};
    for (var role in roles) {
      permissions.addAll(role.getPermissionKeys());
    }
    return permissions.toList();
  }

  /// Check if user has a specific permission through any role
  bool hasPermission(String permissionKey) {
    return roles.any((role) => role.hasPermission(permissionKey));
  }

  factory UserRoleAssignment.fromJson(Map<String, dynamic> json) {
    final roleList = json['roles'] as List? ?? [];
    return UserRoleAssignment(
      userId: json['user_id'] as String,
      roles: List<Role>.from(
        roleList.map((r) => Role.fromJson(r as Map<String, dynamic>)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'roles': roles.map((r) => r.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [userId, roles];
}
