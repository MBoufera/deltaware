import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _workers = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  Future<void> _fetchWorkers() async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
      }
    }
  }

  void _showPermissionsDialog(Map<String, dynamic> worker) {
    final permissions = Map<String, dynamic>.from(worker['permissions'] ?? {});
    bool canManageProducts = permissions['can_manage_products'] == true;
    bool canManageClients = permissions['can_manage_clients'] == true;
    bool canViewAllSales = permissions['can_view_all_sales'] == true;
    bool canCancelSales = permissions['can_cancel_sales'] == true;
    bool canViewReports = permissions['can_view_reports'] == true;
    bool canManageSettings = permissions['can_manage_settings'] == true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Permissions: ${worker['full_name']}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203A43)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPermissionSwitch('Gérer les Produits', canManageProducts, (v) => setStateDialog(() => canManageProducts = v)),
                    _buildPermissionSwitch('Gérer les Clients', canManageClients, (v) => setStateDialog(() => canManageClients = v)),
                    _buildPermissionSwitch('Voir Toutes les Ventes', canViewAllSales, (v) => setStateDialog(() => canViewAllSales = v)),
                    _buildPermissionSwitch('Annuler une Vente', canCancelSales, (v) => setStateDialog(() => canCancelSales = v)),
                    _buildPermissionSwitch('Voir les Rapports', canViewReports, (v) => setStateDialog(() => canViewReports = v)),
                    _buildPermissionSwitch('Gérer les Paramètres', canManageSettings, (v) => setStateDialog(() => canManageSettings = v)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(), 
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF203A43),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    setState(() => _isLoading = true);
                    try {
                      await _supabase.rpc('update_worker_permissions', params: {
                        'p_user_id': worker['id'],
                        'p_permissions': {
                          'can_manage_products': canManageProducts,
                          'can_manage_clients': canManageClients,
                          'can_view_all_sales': canViewAllSales,
                          'can_cancel_sales': canCancelSales,
                          'can_view_reports': canViewReports,
                          'can_manage_settings': canManageSettings,
                        }
                      });
                      await _fetchWorkers();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions updated')));
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildPermissionSwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      activeColor: const Color(0xFF203A43),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      value: value,
      onChanged: onChanged,
    );
  }

  void _showCreateWorkerDialog() {
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String email = '';
    String password = '';
    
    // Default permissions
    bool canManageProducts = false;
    bool canManageClients = false;
    bool canViewAllSales = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Create New Worker',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203A43)),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          decoration: _inputDecoration('Full Name', Icons.person_outline),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          onSaved: (v) => fullName = v!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: _inputDecoration('Email', Icons.email_outlined),
                          validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
                          onSaved: (v) => email = v!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: _inputDecoration('Password', Icons.lock_outline),
                          obscureText: true,
                          validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                          onSaved: (v) => password = v!,
                        ),
                        const SizedBox(height: 24),
                        const Text('Initial Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildPermissionSwitch('Gérer les Produits', canManageProducts, (v) => setStateDialog(() => canManageProducts = v)),
                        _buildPermissionSwitch('Gérer les Clients', canManageClients, (v) => setStateDialog(() => canManageClients = v)),
                        _buildPermissionSwitch('Voir Toutes les Ventes', canViewAllSales, (v) => setStateDialog(() => canViewAllSales = v)),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(), 
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF203A43),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      Navigator.of(context).pop();
                      await _createWorker(fullName, email, password, {
                        'can_manage_products': canManageProducts,
                        'can_manage_clients': canManageClients,
                        'can_view_all_sales': canViewAllSales,
                        'can_cancel_sales': false,
                        'can_view_reports': false,
                        'can_manage_settings': false,
                      });
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF203A43), width: 2),
      ),
    );
  }

  Future<void> _createWorker(String fullName, String email, String password, Map<String, dynamic> initialPermissions) async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${Constants.supabaseUrl}/auth/v1/signup');
      final request = await HttpClient().postUrl(url);
      request.headers.add('apikey', Constants.supabaseAnonKey);
      request.headers.add('Content-Type', 'application/json');
      request.write(jsonEncode({
        'email': email,
        'password': password,
        'data': {
          'full_name': fullName,
          'role': 'worker',
        }
      }));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(responseBody);
        final user = data['user'];
        if (user != null) {
          final userId = user['id'];
          // Set permissions
          await _supabase.rpc('update_worker_permissions', params: {
            'p_user_id': userId,
            'p_permissions': initialPermissions,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker created successfully')));
          }
        } else {
          throw Exception('User data is null. The account might require email confirmation, or the user already exists.');
        }
      } else {
        throw Exception(responseBody);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating worker: $e')));
      }
    } finally {
      _fetchWorkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateWorkerDialog,
        backgroundColor: const Color(0xFF203A43),
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
                  color: Color(0xFF203A43),
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
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C5364)))
                        : _workers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                                    const SizedBox(height: 16),
                                    Text(
                                      'users.no_users'.tr(),
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _workers.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final worker = _workers[index];
                                  final fullName = worker['full_name'] ?? 'Unknown User';
                                  final email = worker['email'] ?? 'No email';
                                  final sales = worker['sales_this_month'] ?? 0;
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF2C5364).withOpacity(0.1),
                                      child: Text(
                                        fullName.toString().substring(0, 1).toUpperCase(), 
                                        style: const TextStyle(color: Color(0xFF2C5364), fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                    title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('$email\nSales this month: $sales'),
                                    isThreeLine: true,
                                    trailing: OutlinedButton.icon(
                                      icon: const Icon(Icons.security, size: 16, color: Color(0xFF2C5364)),
                                      label: const Text('Permissions', style: TextStyle(color: Color(0xFF2C5364))),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF2C5364)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _showPermissionsDialog(worker),
                                    ),
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
