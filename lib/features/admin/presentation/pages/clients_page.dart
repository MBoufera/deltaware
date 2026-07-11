import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../store/presentation/bloc/store_bloc.dart';
import '../widgets/client_dialog.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({Key? key}) : super(key: key);

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'all'; // all, with_debt

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final storeBloc = context.read<StoreBloc>();
      final String? storeId = storeBloc.currentStoreId;

      if (storeId != null) {
        final res = await _supabase.from('client_debts_view').select().eq('store_id', storeId).order('name');
        setState(() {
          _clients = List<Map<String, dynamic>>.from(res);
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading clients: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    _filteredClients = _clients.where((c) {
      final matchesSearch = c['name'].toString().toLowerCase().contains(query) || 
                            (c['phone']?.toString().toLowerCase().contains(query) ?? false);
      final debt = double.tryParse(c['total_debt'].toString()) ?? 0;
      final matchesFilter = _filterType == 'all' || (_filterType == 'with_debt' && debt > 0);
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showClientDialog([Map<String, dynamic>? client]) async {
    final storeBloc = context.read<StoreBloc>();
    final storeId = storeBloc.currentStoreId;
    if (storeId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ClientDialog(client: client, storeId: storeId),
    );
    if (result == true) {
      _loadClients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Clients & Debts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF203A43),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showClientDialog(),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Client', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF203A43)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _applyFilters()),
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildFilterChip('All Clients', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('With Debts', 'with_debt'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                    child: DataTable(
                                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                      columns: const [
                                        DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                        DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                        DataColumn(label: Text('Total Sales', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                        DataColumn(label: Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                        DataColumn(label: Text('Debt Remaining', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                      ],
                                      rows: _filteredClients.map((client) {
                                        final totalSales = double.tryParse(client['total_sales'].toString()) ?? 0;
                                        final totalPaid = double.tryParse(client['total_paid'].toString()) ?? 0;
                                        final totalDebt = double.tryParse(client['total_debt'].toString()) ?? 0;

                                        return DataRow(
                                          cells: [
                                            DataCell(Text(client['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                                            DataCell(Text(client['phone'] ?? '-', style: TextStyle(color: Colors.grey.shade600))),
                                            DataCell(Text('${totalSales.toStringAsFixed(2)} DZD', style: const TextStyle(color: Color(0xFF1E293B)))),
                                            DataCell(Text('${totalPaid.toStringAsFixed(2)} DZD', style: const TextStyle(color: Color(0xFF047857)))),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: totalDebt > 0 ? Colors.red.shade50 : Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '${totalDebt.toStringAsFixed(2)} DZD',
                                                  style: TextStyle(
                                                    color: totalDebt > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Color(0xFF203A43), size: 20),
                                                    onPressed: () => _showClientDialog(client),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () {
                                                      context.push(
                                                        '/dashboard/client_fiche_tier', 
                                                        extra: client,
                                                      ).then((_) => _loadClients()); // Reload after returning
                                                    },
                                                    icon: const Icon(Icons.receipt_long, size: 16),
                                                    label: const Text('Fiche Tier'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF203A43),
                                                      foregroundColor: Colors.white,
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                if (_filteredClients.isEmpty)
                                  Positioned.fill(
                                    top: 56, // data table header height approx
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                                          const SizedBox(height: 16),
                                          Text('No clients found', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filterType = value;
          _applyFilters();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF203A43),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF203A43) : Colors.grey.shade300),
      ),
    );
  }
}
