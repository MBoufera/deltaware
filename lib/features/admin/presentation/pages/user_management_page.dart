import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants.dart';
import '../../../../features/auth/presentation/bloc/permissions_bloc.dart';
import '../../../../features/auth/presentation/bloc/permissions_event.dart';
import '../bloc/role/role_bloc.dart';
import '../bloc/role/role_event.dart';
import '../../../admin/data/models/role_model.dart';
import '../widgets/role_assignment_dialog.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _workers = [];

  static const _primary = Color(0xFF203A43);
  static const _accent = Color(0xFF2C5364);

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
    context.read<RoleBloc>().add(const LoadAllRoles());
  }

  // ─── Data ────────────────────────────────────────────────────────────────

  Future<void> _fetchWorkers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.rpc('get_workers');
      if (mounted) {
        setState(() {
          _workers = List<dynamic>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading workers: $e');
      }
    }
  }

  void _refreshPermissionsIfCurrentUser(String userId) {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null && currentUser.id == userId) {
      final role = currentUser.userMetadata?['role'] ?? '';
      context.read<PermissionsBloc>().add(RefreshPermissions(userId, role));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Role Assignment ─────────────────────────────────────────────────────

  void _showRoleAssignmentDialog(BuildContext ctx, Map<String, dynamic> worker) {
    final roleBloc = ctx.read<RoleBloc>();
    final currentState = roleBloc.state;
    final availableRoles = currentState.roles;
    final assignedRoles = currentState.userRoles?.userId == worker['id']
        ? currentState.userRoles!.roles
        : <Role>[];

    roleBloc.add(LoadUserRoles(worker['id']));

    showDialog<void>(
      context: ctx,
      builder: (_) => RoleAssignmentDialog(
        userName: worker['full_name'] ?? 'User',
        availableRoles: availableRoles,
        assignedRoles: assignedRoles,
        onSyncRoles: (rolesToAdd, rolesToRemove) {
          roleBloc.add(SyncUserRoles(
            userId: worker['id'],
            rolesToAdd: rolesToAdd,
            rolesToRemove: rolesToRemove,
          ));
          _refreshPermissionsIfCurrentUser(worker['id']);
        },
      ),
    ).then((_) => _waitForBlocThenRefresh(roleBloc));
  }

  void _waitForBlocThenRefresh(RoleBloc roleBloc) {
    if (!roleBloc.state.isLoading) {
      _fetchWorkers();
      return;
    }
    int attempts = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
      if (!roleBloc.state.isLoading || attempts > 15) {
        if (mounted) _fetchWorkers();
        return false;
      }
      return true;
    });
  }

  // ─── Edit Profile ────────────────────────────────────────────────────────

  void _showEditUserDialog(Map<String, dynamic> worker) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: worker['full_name'] ?? '');
    final emailCtrl = TextEditingController(text: worker['email'] ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.bold, color: _primary, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: _inputDecoration('Full Name', Icons.person_outline),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  decoration: _inputDecoration('Email', Icons.email_outlined),
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Enter a valid email' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              await _updateWorkerProfile(
                worker['id'],
                nameCtrl.text.trim(),
                emailCtrl.text.trim(),
                oldName: worker['full_name'] ?? '',
                oldEmail: worker['email'] ?? '',
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateWorkerProfile(
    String userId,
    String fullName,
    String email, {
    required String oldName,
    required String oldEmail,
  }) async {
    // Only send what changed
    final newName = fullName != oldName ? fullName : null;
    final newEmail = email != oldEmail ? email : null;
    if (newName == null && newEmail == null) return;

    try {
      await _supabase.rpc('update_worker_profile', params: {
        'p_user_id': userId,
        if (newName != null) 'p_full_name': newName,
        if (newEmail != null) 'p_email': newEmail,
      });
      _showSuccess('Profile updated successfully');
      await _fetchWorkers();
    } catch (e) {
      _showError('Error updating profile: $e');
    }
  }

  // ─── Generate Password ───────────────────────────────────────────────────

  void _showGeneratePasswordDialog(Map<String, dynamic> worker) {
    final userName = worker['full_name'] ?? worker['email'] ?? 'this user';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.key_outlined, color: Colors.orange.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Generate Password',
              style: TextStyle(fontWeight: FontWeight.bold, color: _primary, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will generate a new random password for "$userName" and immediately apply it. '
                'The old password will no longer work.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You must share the new password with the user manually.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _generatePassword(worker['id'], userName);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePassword(String userId, String userName) async {
    try {
      final newPassword = await _supabase.rpc('generate_worker_password', params: {
        'p_user_id': userId,
      });

      if (!mounted) return;

      // Show the generated password in a copyable dialog
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PasswordRevealDialog(
          userName: userName,
          password: newPassword as String,
        ),
      );
    } catch (e) {
      _showError('Error generating password: $e');
    }
  }

  // ─── Delete User ─────────────────────────────────────────────────────────

  void _showDeleteUserDialog(Map<String, dynamic> worker) {
    final userName = worker['full_name'] ?? worker['email'] ?? 'this user';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete User',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.grey.shade800, height: 1.5, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Are you sure you want to permanently delete '),
                    TextSpan(
                      text: '"$userName"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '?\n\nThis will remove their account and all role assignments. '),
                    const TextSpan(
                      text: 'This action cannot be undone.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteWorker(worker['id'], userName);
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWorker(String userId, String userName) async {
    try {
      await _supabase.rpc('delete_worker', params: {'p_user_id': userId});
      _showSuccess('"$userName" has been deleted');
      await _fetchWorkers();
    } catch (e) {
      _showError('Error deleting user: $e');
    }
  }

  // ─── Create Worker ───────────────────────────────────────────────────────

  void _showCreateWorkerDialog() {
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String email = '';
    String password = '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Create New Worker',
          style: TextStyle(fontWeight: FontWeight.bold, color: _primary),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: _inputDecoration('Full Name', Icons.person_outline),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    onSaved: (v) => fullName = v!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _inputDecoration('Email', Icons.email_outlined),
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Invalid email' : null,
                    onSaved: (v) => email = v!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _inputDecoration('Password', Icons.lock_outline),
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Min 6 chars' : null,
                    onSaved: (v) => password = v!,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assign roles after creation using "Assign Roles".',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.of(ctx).pop();
                await _createWorker(fullName, email, password);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
    );
  }

  Future<void> _createWorker(String fullName, String email, String password) async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${Constants.supabaseUrl}/auth/v1/signup');
      final request = await HttpClient().postUrl(url);
      request.headers.add('apikey', Constants.supabaseAnonKey);
      request.headers.add('Content-Type', 'application/json');
      request.write(jsonEncode({
        'email': email,
        'password': password,
        'data': {'full_name': fullName, 'role': 'worker'},
      }));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(body);
        if (data['user'] != null) {
          _showSuccess('Worker created. Assign roles now.');
        } else {
          throw Exception('User data is null — account may require email confirmation.');
        }
      } else {
        throw Exception(body);
      }
    } catch (e) {
      _showError('Error creating worker: $e');
    } finally {
      _fetchWorkers();
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateWorkerDialog,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Worker'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'users.title'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'users.subtitle'.tr(),
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
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: _accent),
                          )
                        : _workers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 64, color: Colors.grey.shade300),
                                    const SizedBox(height: 16),
                                    Text(
                                      'users.no_users'.tr(),
                                      style: TextStyle(
                                          color: Colors.grey.shade500, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _workers.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, index) {
                                  final isCurrentUser = _workers[index]['id'] == _supabase.auth.currentUser?.id;
                                  return _WorkerTile(
                                    worker: _workers[index],
                                    isCurrentUser: isCurrentUser,
                                    onEditProfile: () =>
                                        _showEditUserDialog(_workers[index]),
                                    onGeneratePassword: () =>
                                        _showGeneratePasswordDialog(_workers[index]),
                                    onAssignRoles: () =>
                                        _showRoleAssignmentDialog(ctx, _workers[index]),
                                    onDelete: () =>
                                        _showDeleteUserDialog(_workers[index]),
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

// ─── Worker Tile ─────────────────────────────────────────────────────────────

class _WorkerTile extends StatelessWidget {
  final Map<String, dynamic> worker;
  final bool isCurrentUser;
  final VoidCallback onEditProfile;
  final VoidCallback onGeneratePassword;
  final VoidCallback onAssignRoles;
  final VoidCallback onDelete;

  const _WorkerTile({
    required this.worker,
    required this.isCurrentUser,
    required this.onEditProfile,
    required this.onGeneratePassword,
    required this.onAssignRoles,
    required this.onDelete,
  });

  static const _primary = Color(0xFF2C5364);

  @override
  Widget build(BuildContext context) {
    final fullName = worker['full_name'] ?? 'Unknown User';
    final email = worker['email'] ?? 'No email';
    final sales = worker['sales_this_month'] ?? 0;
    final roles = worker['roles'] as List? ?? [];

    return Container(
      decoration: isCurrentUser
          ? BoxDecoration(
              color: const Color(0xFF203A43).withValues(alpha: 0.04),
              border: const Border(
                left: BorderSide(color: Color(0xFF203A43), width: 4),
              ),
            )
          : null,
      child: ListTile(
        contentPadding: EdgeInsets.only(
          left: isCurrentUser ? 12 : 16,
          right: 16,
          top: 8,
          bottom: 8,
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isCurrentUser
              ? const Color(0xFF203A43)
              : _primary.withValues(alpha: 0.12),
          child: Text(
            fullName.toString().isNotEmpty
                ? fullName.toString()[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: isCurrentUser ? Colors.white : _primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              fullName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF203A43),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            // Role chips
            if (roles.isEmpty)
              Text(
                'No roles assigned',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: roles.map<Widget>((r) {
                  final roleName = r['name']?.toString() ?? '';
                  final isSystem = r['is_system'] == true;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSystem
                          ? _primary.withValues(alpha: 0.08)
                          : Colors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSystem
                            ? _primary.withValues(alpha: 0.35)
                            : Colors.purple.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      roleName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSystem ? _primary : Colors.purple.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 4),
            Text(
              'Sales this month: $sales',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: _primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEditProfile();
              case 'password':
                onGeneratePassword();
              case 'roles':
                onAssignRoles();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => [
            _menuItem('edit', Icons.edit_outlined, 'Edit Profile', Colors.blueGrey),
            _menuItem('password', Icons.key_outlined, 'Generate Password', Colors.orange),
            _menuItem('roles', Icons.badge_outlined, 'Assign Roles', _primary),
            if (!isCurrentUser) ...[
              const PopupMenuDivider(),
              _menuItem('delete', Icons.delete_outline, 'Delete User', Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Password Reveal Dialog ───────────────────────────────────────────────────

class _PasswordRevealDialog extends StatefulWidget {
  final String userName;
  final String password;

  const _PasswordRevealDialog({
    required this.userName,
    required this.password,
  });

  @override
  State<_PasswordRevealDialog> createState() => _PasswordRevealDialogState();
}

class _PasswordRevealDialogState extends State<_PasswordRevealDialog> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.password));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Password Generated',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203A43), fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New password for "${widget.userName}":',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.password,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Color(0xFF203A43),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? Icon(Icons.check_circle, color: Colors.green.shade600, key: const ValueKey('copied'))
                        : IconButton(
                            icon: const Icon(Icons.copy_outlined),
                            color: Colors.grey.shade600,
                            onPressed: _copy,
                            tooltip: 'Copy to clipboard',
                            key: const ValueKey('copy'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copy and share this password with the user now. It will not be shown again.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF203A43),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
