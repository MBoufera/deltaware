import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/role_model.dart';

/// Service for managing roles and permissions
class RoleService {
  final SupabaseClient _supabase;

  RoleService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// List all available roles with their permissions
  Future<List<Role>> listAllRoles() async {
    try {
      final response = await _supabase.rpc('list_roles_with_permissions');
      if (response == null) return [];
      
      final rolesList = response as List;
      return rolesList.map((r) => Role.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load roles: $e');
    }
  }

  /// Get roles and permissions for a specific user
  Future<UserRoleAssignment> getUserRoles(String userId, {String? storeId}) async {
    try {
      final params = <String, dynamic>{'p_user_id': userId};
      if (storeId != null) params['p_store_id'] = storeId;
      final response = await _supabase.rpc(
        'get_user_roles_with_permissions',
        params: params,
      );
      
      if (response == null || response.isEmpty) {
        return UserRoleAssignment(userId: userId, roles: []);
      }

      final roles = List.from(response).map((r) => Role.fromJson(r as Map<String, dynamic>)).toList();
      
      return UserRoleAssignment(userId: userId, roles: roles);
    } catch (e) {
      throw Exception('Failed to load user roles: $e');
    }
  }

  /// Get all available permissions grouped by category
  Future<Map<String, List<AppPermission>>> listAllPermissions() async {
    try {
      final response = await _supabase.rpc('list_all_permissions');
      if (response == null) return {};

      final permissionMap = response as Map<String, dynamic>;
      final result = <String, List<AppPermission>>{};

      permissionMap.forEach((category, permissions) {
        if (permissions is List) {
          result[category] = permissions
              .map((p) => AppPermission.fromJson(p as Map<String, dynamic>))
              .toList();
        }
      });

      return result;
    } catch (e) {
      throw Exception('Failed to load permissions: $e');
    }
  }

  /// Create a new custom role
  Future<String> createRole({
    required String name,
    required String? description,
    required List<String> permissionKeys,
  }) async {
    try {
      final roleId = await _supabase.rpc(
        'create_role',
        params: {
          'p_name': name,
          'p_description': description,
          'p_permission_keys': permissionKeys,
        },
      );

      return roleId as String;
    } catch (e) {
      throw Exception('Failed to create role: $e');
    }
  }

  /// Update an existing role
  Future<void> updateRole({
    required String roleId,
    required String name,
    required String? description,
    required List<String> permissionKeys,
  }) async {
    try {
      await _supabase.rpc(
        'update_role',
        params: {
          'p_role_id': roleId,
          'p_name': name,
          'p_description': description,
          'p_permission_keys': permissionKeys,
        },
      );
    } catch (e) {
      throw Exception('Failed to update role: $e');
    }
  }

  /// Delete a role (only non-system roles can be deleted)
  Future<void> deleteRole(String roleId) async {
    try {
      await _supabase.from('roles').delete().eq('id', roleId);
    } catch (e) {
      throw Exception('Failed to delete role: $e');
    }
  }

  /// Assign a role to a user
  Future<void> assignRoleToUser(String userId, String roleId, {String? storeId}) async {
    try {
      final params = <String, dynamic>{
        'p_user_id': userId,
        'p_role_id': roleId,
      };
      if (storeId != null) params['p_store_id'] = storeId;
      await _supabase.rpc(
        'assign_role_to_user',
        params: params,
      );
    } catch (e) {
      throw Exception('Failed to assign role: $e');
    }
  }

  /// Remove a role from a user
  Future<void> removeRoleFromUser(String userId, String roleId, {String? storeId}) async {
    try {
      final params = <String, dynamic>{
        'p_user_id': userId,
        'p_role_id': roleId,
      };
      if (storeId != null) params['p_store_id'] = storeId;
      await _supabase.rpc(
        'remove_role_from_user',
        params: params,
      );
    } catch (e) {
      throw Exception('Failed to remove role: $e');
    }
  }

  /// Get user permissions through their roles
  Future<List<String>> getUserPermissions(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_permissions',
        params: {'p_user_id': userId},
      );

      if (response == null) return [];
      
      return List<String>.from(response as List);
    } catch (e) {
      throw Exception('Failed to load user permissions: $e');
    }
  }

  /// Get all users (for role assignment UI)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase.rpc('get_workers');
      if (response == null) return [];

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }
}
