/// Role Model - Represents a user role
class Role {
  final String id;
  final String name;
  final String? description;
  final bool isSystem;
  final List<Permission> permissions;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Role({
    required this.id,
    required this.name,
    this.description,
    this.isSystem = false,
    this.permissions = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((p) => Permission.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
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
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Role copyWith({
    String? id,
    String? name,
    String? description,
    bool? isSystem,
    List<Permission>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isSystem: isSystem ?? this.isSystem,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Permission Model
class Permission {
  final int id;
  final String name;
  final String? description;
  final String category;

  Permission({
    required this.id,
    required this.name,
    this.description,
    required this.category,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'general',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
    };
  }
}

/// User Role Model
class UserRole {
  final String userId;
  final String roleName;
  final String roleId;
  final List<String> permissions;

  UserRole({
    required this.userId,
    required this.roleName,
    required this.roleId,
    this.permissions = const [],
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      userId: json['id'] as String,
      roleName: json['name'] as String,
      roleId: json['id'] as String,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userId,
      'name': roleName,
      'permissions': permissions,
    };
  }
}
