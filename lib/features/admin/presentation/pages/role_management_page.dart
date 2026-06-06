import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  late final Future<List<Map<String, dynamic>>> _futureRoles;

  @override
  void initState() {
    super.initState();
    _futureRoles = _fetchRoles();
  }

  Future<List<Map<String, dynamic>>> _fetchRoles() async {
    try {
      // Query roles and join with permissions
      final response = await Supabase.instance.client
          .from('roles')
          .select('id, name, description, role_permissions(permissions(name))');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching roles: $e');
      return [];
    }
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
              const Text(
                'Roles & Permissions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203A43),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage what each role can access.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _futureRoles,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF2C5364)));
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Ensure the SQL schema is created.\nError: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }

                        final roles = snapshot.data ?? [];

                        if (roles.isEmpty) {
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
                          padding: const EdgeInsets.all(16),
                          itemCount: roles.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final role = roles[index];
                            final roleName = role['name'] ?? 'Unknown Role';
                            final description = role['description'] ?? 'No description';
                            
                            List<String> permissionsList = [];
                            try {
                              final rolePerms = role['role_permissions'] as List<dynamic>?;
                              if (rolePerms != null) {
                                for (var rp in rolePerms) {
                                  final p = rp['permissions'];
                                  if (p != null && p['name'] != null) {
                                    permissionsList.add(p['name']);
                                  }
                                }
                              }
                            } catch (_) {}

                            return Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF2C5364).withValues(alpha: 0.1),
                                  child: const Icon(Icons.security, color: Color(0xFF2C5364)),
                                ),
                                title: Text(roleName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
                                subtitle: Text(description),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Text('Assigned Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        if (permissionsList.isEmpty)
                                          Text('No permissions assigned', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
                                        else
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: permissionsList.map((perm) => Chip(
                                              label: Text(perm, style: const TextStyle(fontSize: 12)),
                                              backgroundColor: Colors.blue.shade50,
                                              side: BorderSide(color: Colors.blue.shade200),
                                            )).toList(),
                                          ),
                                        const SizedBox(height: 16),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              // TODO: Open dialog to edit permissions
                                            },
                                            icon: const Icon(Icons.edit, size: 16, color: Color(0xFF2C5364)),
                                            label: const Text('Edit Permissions', style: TextStyle(color: Color(0xFF2C5364))),
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
