import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkersPage extends StatefulWidget {
  const WorkersPage({super.key});

  @override
  State<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends State<WorkersPage> {
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
              title: Text('Permissions: ${worker['full_name']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('Gérer les Produits'),
                      value: canManageProducts,
                      onChanged: (v) => setStateDialog(() => canManageProducts = v),
                    ),
                    SwitchListTile(
                      title: const Text('Gérer les Clients'),
                      value: canManageClients,
                      onChanged: (v) => setStateDialog(() => canManageClients = v),
                    ),
                    SwitchListTile(
                      title: const Text('Voir Toutes les Ventes'),
                      value: canViewAllSales,
                      onChanged: (v) => setStateDialog(() => canViewAllSales = v),
                    ),
                    SwitchListTile(
                      title: const Text('Annuler une Vente'),
                      value: canCancelSales,
                      onChanged: (v) => setStateDialog(() => canCancelSales = v),
                    ),
                    SwitchListTile(
                      title: const Text('Voir les Rapports'),
                      value: canViewReports,
                      onChanged: (v) => setStateDialog(() => canViewReports = v),
                    ),
                    SwitchListTile(
                      title: const Text('Gérer les Paramètres'),
                      value: canManageSettings,
                      onChanged: (v) => setStateDialog(() => canManageSettings = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final msg = ScaffoldMessenger.of(context);
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
                      _fetchWorkers();
                      if (mounted) {
                        msg.showSnackBar(const SnackBar(content: Text('Permissions updated')));
                      }
                    } catch (e) {
                      if (mounted) {
                        msg.showSnackBar(SnackBar(content: Text('Error: $e')));
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('Worker Management'),
        backgroundColor: const Color(0xFF1A2A32),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registered Workers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2A32))),
              const SizedBox(height: 8),
              const Text('Manage accounts and feature permissions', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _workers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final worker = _workers[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1A2A32),
                        child: Text(worker['full_name'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(worker['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${worker['email']}\nSales this month: ${worker['sales_this_month']}'),
                      isThreeLine: true,
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.security, size: 16),
                        label: const Text('Permissions'),
                        onPressed: () => _showPermissionsDialog(worker),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
