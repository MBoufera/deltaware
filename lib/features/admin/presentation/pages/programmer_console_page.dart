import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class ProgrammerConsolePage extends StatefulWidget {
  const ProgrammerConsolePage({super.key});

  @override
  State<ProgrammerConsolePage> createState() => _ProgrammerConsolePageState();
}

class _ProgrammerConsolePageState extends State<ProgrammerConsolePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _superAdmins = [];
  List<dynamic> _stores = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSaaSData();
  }

  Future<void> _fetchSaaSData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.rpc('get_programmer_saas_data');
      if (mounted) {
        setState(() {
          _superAdmins = List<dynamic>.from(response['super_admins'] ?? []);
          _stores = List<dynamic>.from(response['stores'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading SaaS data: $e');
      }
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

  Future<void> _createSuperAdmin(String fullName, String email, String password) async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${Constants.supabaseUrl}/auth/v1/signup');
      final request = await HttpClient().postUrl(url);
      request.headers.add('apikey', Constants.supabaseAnonKey);
      request.headers.add('Content-Type', 'application/json');
      request.write(
        jsonEncode({
          'email': email,
          'password': password,
          'data': {
            'full_name': fullName,
            'is_super_admin': true,
            'role': 'admin',
          },
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(body);
        if (data['user'] != null) {
          _showSuccess('Store Owner (Super Admin) account created successfully!');
        } else {
          throw Exception('User data is null — check confirmation settings.');
        }
      } else {
        throw Exception(body);
      }
    } catch (e) {
      _showError('Error creating store owner: $e');
    } finally {
      _fetchSaaSData();
    }
  }

  void _showCreateClientDialog() {
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String email = '';
    String password = '';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2027).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_business_rounded,
                color: Color(0xFF2C5364),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Add Store Owner',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Create a new Super Admin account. This user will act as the store owner and can manage their own stores, settings, categories, and workers.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _buildFormTextField(
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    onSaved: (v) => fullName = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  _buildFormTextField(
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                    onSaved: (v) => email = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  _buildFormTextField(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                    onSaved: (v) => password = v!,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C5364),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      Navigator.of(ctx).pop();
                      _createSuperAdmin(fullName, email, password);
                    }
                  },
                  child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormTextField({
    required String label,
    required IconData icon,
    required FormFieldValidator<String>? validator,
    required FormFieldSetter<String>? onSaved,
    bool obscureText = false,
  }) {
    return TextFormField(
      obscureText: obscureText,
      validator: validator,
      onSaved: onSaved,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
          borderSide: const BorderSide(color: Color(0xFF2C5364), width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter SaaS clients by search query
    final filteredAdmins = _superAdmins.where((admin) {
      final name = admin['full_name'].toString().toLowerCase();
      final email = admin['email'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    final totalClients = _superAdmins.length;
    final totalStores = _stores.length;
    final totalWorkers = _stores.fold<int>(
      0,
      (sum, store) => sum + (store['members'] as List).where((m) => m['role'] == 'worker').length,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: _buildHeader(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF2C5364))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDashboardKpis(totalClients, totalStores, totalWorkers),
                  const SizedBox(height: 32),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  _buildClientsSection(filteredAdmins),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: const Color(0xFF0F2027),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.developer_mode_rounded, color: Colors.cyanAccent),
          ),
          const SizedBox(width: 12),
          const Text(
            'Developer Control Center',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 0.5),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _fetchSaaSData,
          tooltip: 'Refresh Data',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          onPressed: () {
            context.read<AuthBloc>().add(LogoutRequested());
            context.go('/');
          },
          tooltip: 'Sign out',
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDashboardKpis(int clientsCount, int storesCount, int workersCount) {
    return Row(
      children: [
        _buildKpiCard(
          title: 'TOTAL SAAS CLIENTS',
          value: '$clientsCount',
          subtitle: 'Store Owners / Super Admins',
          icon: Icons.supervised_user_circle_outlined,
          color: const Color(0xFF2563EB),
          bgGradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        ),
        const SizedBox(width: 20),
        _buildKpiCard(
          title: 'ACTIVE STORES',
          value: '$storesCount',
          subtitle: 'Total stores managed',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF7C3AED),
          bgGradient: const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),
        const SizedBox(width: 20),
        _buildKpiCard(
          title: 'ENROLLED COLLABORATORS',
          value: '$workersCount',
          subtitle: 'Active staff & workers',
          icon: Icons.badge_outlined,
          color: const Color(0xFF0D9488),
          bgGradient: const [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> bgGradient,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color.withValues(alpha: 0.8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search clients by name or email...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _showCreateClientDialog,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text(
            'Add Store Owner',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C5364),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildClientsSection(List<dynamic> clients) {
    if (clients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60.0),
          child: Column(
            children: [
              Icon(Icons.supervised_user_circle_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'No store owners found.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registered Store Owners & Stores',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clients.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final client = clients[index];
            final clientStores = _stores.where((s) => s['owner_id'] == client['id']).toList();

            return _ClientCard(
              client: client,
              stores: clientStores,
            );
          },
        ),
      ],
    );
  }
}

class _ClientCard extends StatefulWidget {
  final Map<String, dynamic> client;
  final List<dynamic> stores;

  const _ClientCard({required this.client, required this.stores});

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.client['full_name'] ?? 'Store Owner';
    final email = widget.client['email'] ?? 'No email';
    final createdAt = widget.client['created_at'] != null
        ? DateTime.parse(widget.client['created_at'])
        : DateTime.now();
    final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
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
            )
          ],
          border: Border.all(
            color: _isHovered ? const Color(0xFF2C5364).withValues(alpha: 0.2) : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF0F2027).withValues(alpha: 0.08),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'O',
              style: const TextStyle(color: Color(0xFF0F2027), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '$email  •  Registered on $formattedDate',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Text(
                        'STORES OWNED BY $name',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.stores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'This store owner has not created any stores yet.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.stores.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final store = widget.stores[index];
                        final members = List<dynamic>.from(store['members'] ?? []);
                        final workers = members.where((m) => m['role'] == 'worker').toList();
                        final admins = members.where((m) => m['role'] == 'admin' || m['role'] == 'super_admin').toList();

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
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
                                        store['name'] ?? 'Unnamed Store',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                      ),
                                      if (store['subtitle'] != null && store['subtitle'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          store['subtitle'],
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${admins.length + workers.length} Members',
                                      style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24, color: Color(0xFFF1F5F9)),
                              const Text(
                                'Collaborators / Workers:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),
                              if (workers.isEmpty)
                                const Text(
                                  'No workers added to this store.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: workers.map<Widget>((worker) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                worker['full_name'] ?? 'Worker',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                              ),
                                              Text(
                                                worker['email'] ?? '',
                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
