import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/role_model.dart';

class RoleService {
  final SupabaseClient _supabase;

  RoleService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get all roles with their permissions
  Future<List<Role>> getRolesWithPermissions() async {
    try {
      final response = await _supabase.rpc('get_roles_with_permissions');
      if (response == null) return [];
      
      final rolesList = (response as List<dynamic>).cast<Map<String, dynamic>>();
      return rolesList.map((r) => Role.fromJson(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch roles: $e');
    }
  }

  /// Get all available permissions
  Future<List<Permission>> getPermissions() async {
    try {
      final response = await _supabase.rpc('get_permissions');
      if (response == null) return [];
      
      final permissionsList =
          (response as List<dynamic>).cast<Map<String, dynamic>>();
      return permissionsList.map((p) => Permission.fromJson(p)).toList();
    } catch (e) {
      throw Exception('Failed to fetch permissions: $e');
    }
  }

  /// Create a new role
  Future<Role> createRole({
    required String name,
    required String description,
    required List<int> permissionIds,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_role',
        params: {
          'p_name': name,
          'p_description': description,
          'p_permission_ids': permissionIds,
        },
      );

      if (response == null) throw Exception('Failed to create role');
      return Role.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create role: $e');
    }
  }

  /// Update an existing role
  Future<Role> updateRole({
    required String roleId,
    required String name,
    required String description,
    required List<int> permissionIds,
  }) async {
    try {
      final response = await _supabase.rpc(
        'update_role',
        params: {
          'p_role_id': roleId,
          'p_name': name,
          'p_description': description,
          'p_permission_ids': permissionIds,
        },
      );

      if (response == null) throw Exception('Failed to update role');
      return Role.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update role: $e');
    }
  }

  /// Delete a role
  Future<void> deleteRole(String roleId) async {
    try {
      await _supabase.rpc('delete_role', params: {'p_role_id': roleId});
    } catch (e) {
      throw Exception('Failed to delete role: $e');
    }
  }

  /// Assign a role to a user
  Future<void> assignRoleToUser({
    required String userId,
    required String roleId,
  }) async {
    try {
      await _supabase.rpc(
        'assign_role_to_user',
        params: {
          'p_user_id': userId,
          'p_role_id': roleId,
        },
      );
    } catch (e) {
      throw Exception('Failed to assign role: $e');
    }
  }

  /// Remove a role from a user
  Future<void> removeRoleFromUser({
    required String userId,
    required String roleId,
  }) async {
    try {
      await _supabase.rpc(
        'remove_role_from_user',
        params: {
          'p_user_id': userId,
          'p_role_id': roleId,
        },
      );
    } catch (e) {
      throw Exception('Failed to remove role: $e');
    }
  }

  /// Get user with their roles and permissions
  Future<Map<String, dynamic>> getUserWithRoles(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_with_roles',
        params: {'p_user_id': userId},
      );

      if (response == null) {
        return {'id': userId, 'roles': [], 'permissions': []};
      }

      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch user roles: $e');
    }
  }

  /// Get workers with their roles
  Future<List<Map<String, dynamic>>> getWorkersWithRoles() async {
    try {
      final response = await _supabase.rpc('get_workers_with_roles');
      if (response == null) return [];

      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch workers: $e');
    }
  }
}
