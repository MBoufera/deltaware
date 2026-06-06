import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  late final Future<List<Map<String, dynamic>>> _futureUsers;

  @override
  void initState() {
    super.initState();
    _futureUsers = _fetchUsers();
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    try {
      // Query profiles and join with roles
      // Make sure you have run the SQL script for public.profiles and public.roles
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, user_roles(role_id, roles(name))');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching users: $e');
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
                'Manage Users',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203A43),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assign roles and update profiles.',
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
                      future: _futureUsers,
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

                        final users = snapshot.data ?? [];

                        if (users.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No users found.',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: users.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final fullName = user['full_name'] ?? 'Unknown User';
                            final email = user['email'] ?? 'No email';
                            
                            // Parse roles safely based on the join structure
                            String roleDisplay = 'No Role';
                            try {
                              final userRoles = user['user_roles'] as List<dynamic>?;
                              if (userRoles != null && userRoles.isNotEmpty) {
                                final roleData = userRoles.first['roles'];
                                if (roleData != null) {
                                  roleDisplay = roleData['name'] ?? 'No Role';
                                }
                              }
                            } catch (_) {}

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF2C5364).withValues(alpha: 0.1),
                                child: Text(fullName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF2C5364), fontWeight: FontWeight.bold)),
                              ),
                              title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(email),
                              trailing: Chip(
                                label: Text(roleDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                backgroundColor: roleDisplay == 'Admin' 
                                    ? Colors.red.shade100 
                                    : roleDisplay == 'Staff' 
                                        ? Colors.orange.shade100 
                                        : Colors.blue.shade100,
                                labelStyle: TextStyle(
                                  color: roleDisplay == 'Admin' 
                                      ? Colors.red.shade900 
                                      : roleDisplay == 'Staff' 
                                          ? Colors.orange.shade900 
                                          : Colors.blue.shade900,
                                ),
                              ),
                              onTap: () {
                                // TODO: Show dialog to change role
                              },
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
