import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/role/role_bloc.dart';
import '../bloc/role/role_event.dart';
import '../bloc/role/role_state.dart';
import '../widgets/role_creation_dialog.dart';
import '../widgets/role_edit_dialog.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  @override
  void initState() {
    super.initState();
    // Load all roles and permissions when page initializes
    context.read<RoleBloc>().add(const LoadAllRoles());
    context.read<RoleBloc>().add(const LoadAllPermissions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roles Management',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203A43),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create, edit, and manage roles and their permissions',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateRoleDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New Role'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5364),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BlocConsumer<RoleBloc, RoleState>(
                  listener: (context, state) {
                    if (state.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.error!),
                          backgroundColor: Colors.red,
                        ),
                      );
                      context.read<RoleBloc>().add(const ClearRoleError());
                    }
                    if (state.successMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.successMessage!),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state.isLoading && state.roles.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF2C5364)),
                      );
                    }

                    if (state.roles.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.security, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No roles found.',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: state.roles.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final role = state.roles[index];

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2C5364).withValues(alpha: 0.1),
                              child: const Icon(Icons.security, color: Color(0xFF2C5364)),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    role.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF203A43),
                                    ),
                                  ),
                                ),
                                if (role.isSystem)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      border: Border.all(color: Colors.blue.shade200),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'System',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              role.description ?? 'No description',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Permissions:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    if (role.permissions.isEmpty)
                                      Text(
                                        'No permissions assigned',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12,
                                        ),
                                      )
                                    else
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: role.permissions.map((perm) {
                                          return Chip(
                                            label: Text(
                                              perm.name,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            backgroundColor: Colors.blue.shade50,
                                            side: BorderSide(color: Colors.blue.shade200),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          );
                                        }).toList(),
                                      ),
                                    const SizedBox(height: 12),
                                    if (role.permissions.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '${role.permissions.length} permission${role.permissions.length > 1 ? 's' : ''}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _showEditRoleDialog(context, role, state),
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF2C5364),
                                          ),
                                        ),
                                        if (!role.isSystem)
                                          TextButton.icon(
                                            onPressed: () => _showDeleteConfirmation(context, role),
                                            icon: const Icon(Icons.delete, size: 16),
                                            label: const Text('Delete', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateRoleDialog(BuildContext context) {
    final roleState = context.read<RoleBloc>().state;
    showDialog(
      context: context,
      builder: (context) => RoleCreationDialog(
        permissions: roleState.permissions,
        onCreate: (name, description, permissionKeys) {
          context.read<RoleBloc>().add(
            CreateRole(
              name: name,
              description: description,
              permissionKeys: permissionKeys,
            ),
          );
        },
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, dynamic role, RoleState state) {
    showDialog(
      context: context,
      builder: (context) => RoleEditDialog(
        role: role,
        permissions: state.permissions,
        onUpdate: (name, description, permissionKeys) {
          context.read<RoleBloc>().add(
            UpdateRole(
              roleId: role.id,
              name: name,
              description: description,
              permissionKeys: permissionKeys,
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Role?'),
        content: Text('Are you sure you want to delete "${role.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<RoleBloc>().add(DeleteRole(role.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
