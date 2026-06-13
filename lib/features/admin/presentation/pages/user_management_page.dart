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
  String _searchQuery = '';

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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF203A43).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, color: Color(0xFF203A43), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 18),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF203A43),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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
    final newName = fullName != oldName ? fullName : null;
    final newEmail = email != oldEmail ? email : null;
    if (newName == null && newEmail == null) return;

    try {
      await _supabase.rpc('update_worker_profile', params: {
        'p_user_id': userId,
        'p_full_name': ?newName,
        'p_email': ?newEmail,
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.key_outlined, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Generate Password',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 18),
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
                style: TextStyle(color: Colors.grey.shade700, height: 1.4, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You must share the new password with the user manually.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _generatePassword(worker['id'], userName);
                  },
                  child: const Text(
                    'Generate',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade600, height: 1.5, fontSize: 14),
                children: [
                  const TextSpan(text: 'Are you sure you want to permanently delete '),
                  TextSpan(
                    text: '"$userName"',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const TextSpan(text: '?\n\nThis will remove their account and all role assignments. '),
                  const TextSpan(
                    text: 'This action cannot be undone.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _deleteWorker(worker['id'], userName);
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

    Widget buildField({
      required String label,
      required IconData icon,
      required FormFieldValidator<String>? validator,
      required FormFieldSetter<String>? onSaved,
      bool obscureText = false,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            obscureText: obscureText,
            validator: validator,
            onSaved: onSaved,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF203A43), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF203A43).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_add_rounded, color: Color(0xFF203A43), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create New Worker',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildField(
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    onSaved: (v) => fullName = v!,
                  ),
                  const SizedBox(height: 16),
                  buildField(
                    label: 'Email',
                    icon: Icons.email_outlined,
                    validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
                    onSaved: (v) => email = v!,
                  ),
                  const SizedBox(height: 16),
                  buildField(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                    onSaved: (v) => password = v!,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assign roles after creation using "Assign Roles".',
                            style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF203A43),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      Navigator.of(ctx).pop();
                      await _createWorker(fullName, email, password);
                    }
                  },
                  child: const Text(
                    'Create',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF203A43), width: 2),
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Expanded(
      child: _KpiCardContainer(
        title: title,
        value: value,
        icon: icon,
        iconColor: iconColor,
        iconBgColor: iconBgColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers = _workers.length;
    final adminCount = _workers.where((w) {
      final roles = w['roles'] as List? ?? [];
      return roles.any((r) => r['name'].toString().toLowerCase().contains('admin'));
    }).length;
    final standardCount = totalUsers - adminCount;
    final totalSales = _workers.fold<int>(0, (sum, w) => sum + (w['sales_this_month'] as num? ?? 0).toInt());

    final filteredWorkers = _workers.where((w) {
      final name = (w['full_name'] ?? '').toString().toLowerCase();
      final email = (w['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'users.title'.tr(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2A32),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'users.subtitle'.tr(),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton.icon(
                        onPressed: _showCreateWorkerDialog,
                        icon: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: const Text(
                          'Add Worker',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF203A43),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF203A43).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // KPI Stats Grid Row
              Row(
                children: [
                  _buildKpiCard(
                    title: 'TOTAL UTILISATEURS',
                    value: '$totalUsers',
                    icon: Icons.people_outline_rounded,
                    iconColor: const Color(0xFF203A43),
                    iconBgColor: const Color(0xFF203A43).withValues(alpha: 0.08),
                  ),
                  const SizedBox(width: 16),
                  _buildKpiCard(
                    title: 'ADMINISTRATEURS',
                    value: '$adminCount',
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBgColor: const Color(0xFFEFF6FF),
                  ),
                  const SizedBox(width: 16),
                  _buildKpiCard(
                    title: 'COLLABORATEURS',
                    value: '$standardCount',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF7E22CE),
                    iconBgColor: const Color(0xFFF3E8FF),
                  ),
                  const SizedBox(width: 16),
                  _buildKpiCard(
                    title: 'VENTES DU MOIS',
                    value: '$totalSales',
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF047857),
                    iconBgColor: const Color(0xFFECFDF5),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search Filter Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou email...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(height: 24),
              
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF203A43),
                        ),
                      )
                    : filteredWorkers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.people_outline_rounded,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Aucun utilisateur ne correspond à votre recherche'
                                      : 'users.no_users'.tr(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: filteredWorkers.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (ctx, index) {
                              final isCurrentUser = filteredWorkers[index]['id'] == _supabase.auth.currentUser?.id;
                              return _UserCard(
                                worker: filteredWorkers[index],
                                isCurrentUser: isCurrentUser,
                                onEditProfile: () => _showEditUserDialog(filteredWorkers[index]),
                                onGeneratePassword: () => _showGeneratePasswordDialog(filteredWorkers[index]),
                                onAssignRoles: () => _showRoleAssignmentDialog(ctx, filteredWorkers[index]),
                                onDelete: () => _showDeleteUserDialog(filteredWorkers[index]),
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
}

// ─── User Card ─────────────────────────────────────────────────────────────
class _UserCard extends StatefulWidget {
  final Map<String, dynamic> worker;
  final bool isCurrentUser;
  final VoidCallback onEditProfile;
  final VoidCallback onGeneratePassword;
  final VoidCallback onAssignRoles;
  final VoidCallback onDelete;

  const _UserCard({
    required this.worker,
    required this.isCurrentUser,
    required this.onEditProfile,
    required this.onGeneratePassword,
    required this.onAssignRoles,
    required this.onDelete,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isHovered = false;

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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.worker['full_name'] ?? 'Unknown User';
    final email = widget.worker['email'] ?? 'No email';
    final sales = widget.worker['sales_this_month'] ?? 0;
    final roles = widget.worker['roles'] as List? ?? [];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.05 : 0.02),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF203A43).withValues(alpha: 0.15)
                  : widget.isCurrentUser
                      ? const Color(0xFF203A43).withValues(alpha: 0.3)
                      : Colors.grey.shade200,
              width: widget.isCurrentUser || _isHovered ? 2.0 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: widget.isCurrentUser
                      ? const Color(0xFF203A43)
                      : const Color(0xFF203A43).withValues(alpha: 0.08),
                  child: Text(
                    fullName.toString().isNotEmpty
                        ? fullName.toString()[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: widget.isCurrentUser ? Colors.white : const Color(0xFF203A43),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (widget.isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (roles.isEmpty)
                        Text(
                          'No roles assigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: roles.map<Widget>((r) {
                            final roleName = r['name']?.toString() ?? '';
                            final isSystem = r['is_system'] == true;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSystem
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSystem
                                      ? const Color(0xFFDBEAFE)
                                      : const Color(0xFFE9D5FF),
                                ),
                              ),
                              child: Text(
                                roleName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSystem
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF7E22CE),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: const Color(0xFF047857),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ventes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$sales',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (email != 'superadmin@deltaware.dz') ...[
                  const SizedBox(width: 16),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF203A43)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          widget.onEditProfile();
                        case 'password':
                          widget.onGeneratePassword();
                        case 'roles':
                          widget.onAssignRoles();
                        case 'delete':
                          widget.onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      _menuItem('edit', Icons.edit_outlined, 'Edit Profile', const Color(0xFF334155)),
                      _menuItem('password', Icons.key_outlined, 'Generate Password', const Color(0xFFD97706)),
                      _menuItem('roles', Icons.badge_outlined, 'Assign Roles', const Color(0xFF0F766E)),
                      if (!widget.isCurrentUser) ...[
                        const PopupMenuDivider(),
                        _menuItem('delete', Icons.delete_outline_rounded, 'Delete User', const Color(0xFFB91C1C)),
                      ],
                    ],
                  ),
                ] else ...[
                  const SizedBox(width: 16),
                  Tooltip(
                    message: 'Protected Account',
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Password Generated',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 18),
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
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        letterSpacing: 2,
                        color: Color(0xFF203A43),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), key: ValueKey('copied'))
                        : MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: const Icon(Icons.copy_rounded),
                              color: Colors.grey.shade600,
                              onPressed: _copy,
                              tooltip: 'Copy to clipboard',
                              key: const ValueKey('copy'),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copy and share this password with the user now. It will not be shown again.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
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

class _KpiCardContainer extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _KpiCardContainer({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  State<_KpiCardContainer> createState() => _KpiCardContainerState();
}

class _KpiCardContainerState extends State<_KpiCardContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered 
                  ? const Color(0xFF203A43).withValues(alpha: 0.15) 
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.02),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
