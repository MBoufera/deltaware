import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../store/presentation/bloc/store_bloc.dart';
import '../bloc/suppliers/suppliers_bloc.dart';
import '../bloc/suppliers/suppliers_event.dart';
import '../bloc/suppliers/suppliers_state.dart';
import '../widgets/supplier_dialog.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({Key? key}) : super(key: key);

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'all'; // all, with_debt
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuppliers();
    });
  }

  void _loadSuppliers() {
    final storeBloc = context.read<StoreBloc>();
    final storeId = storeBloc.currentStoreId;
    if (storeId != null) {
      context.read<SuppliersBloc>().add(LoadSuppliers(storeId));
    }
  }

  void _showSupplierDialog([Map<String, dynamic>? supplier]) {
    final storeBloc = context.read<StoreBloc>();
    final storeId = storeBloc.currentStoreId;
    if (storeId == null) return;

    showDialog(
      context: context,
      builder: (_) => SupplierDialog(supplier: supplier, storeId: storeId),
    );
  }

  List<Map<String, dynamic>> _getFilteredSuppliers(List<Map<String, dynamic>> suppliers) {
    final query = _searchController.text.toLowerCase();
    return suppliers.where((s) {
      final matchesSearch = s['name'].toString().toLowerCase().contains(query) || 
                            (s['phone']?.toString().toLowerCase().contains(query) ?? false);
      final debt = double.tryParse(s['total_debt'].toString()) ?? 0;
      final matchesFilter = _filterType == 'all' || (_filterType == 'with_debt' && debt > 0);
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canManageClients.key, // You can make a canManageSuppliers permission later
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Suppliers & Debts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B))),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF203A43),
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 24.0, top: 8.0, bottom: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => _showSupplierDialog(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
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
        body: BlocBuilder<SuppliersBloc, SuppliersState>(
          builder: (context, state) {
            if (state is SuppliersLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF203A43)));
            } else if (state is SuppliersError) {
              return Center(child: Text('Error: ${state.message}', style: const TextStyle(color: Colors.red)));
            } else if (state is SuppliersLoaded) {
              final filteredSuppliers = _getFilteredSuppliers(state.suppliers);
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() {}),
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
                        _buildFilterChip('All Suppliers', 'all'),
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
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                columns: const [
                                  DataColumn(label: Text('Supplier Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                  DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                  DataColumn(label: Text('Total Purchases', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                  DataColumn(label: Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                  DataColumn(label: Text('Debt Remaining', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                ],
                                rows: filteredSuppliers.map((supplier) {
                                  final totalPurchases = double.tryParse(supplier['total_purchases'].toString()) ?? 0;
                                  final totalPaid = double.tryParse(supplier['total_paid'].toString()) ?? 0;
                                  final totalDebt = double.tryParse(supplier['total_debt'].toString()) ?? 0;

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(supplier['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                                      DataCell(Text(supplier['phone'] ?? '-', style: TextStyle(color: Colors.grey.shade600))),
                                      DataCell(Text('${totalPurchases.toStringAsFixed(2)} DZD', style: const TextStyle(color: Color(0xFF1E293B)))),
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
                                              onPressed: () => _showSupplierDialog(supplier),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                context.push(
                                                  '/dashboard/supplier_fiche_tier', 
                                                  extra: supplier,
                                                );
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
                                        )
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
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
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF203A43),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF203A43) : Colors.grey.shade300),
      ),
    );
  }
}
