import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../store/presentation/bloc/store_state.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  String _filterMode = 'all'; // 'all' or 'low'
  Map<String, dynamic>? _selectedProduct;

  final _searchController = TextEditingController();
  final _superGrosController = TextEditingController();
  final _grosController = TextEditingController();
  final _detailController = TextEditingController();
  final _alertThresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _superGrosController.dispose();
    _grosController.dispose();
    _detailController.dispose();
    _alertThresholdController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    try {
      final storeState = context.read<StoreBloc>().state;
      final storeId = storeState is StoresLoaded ? storeState.selectedStore?.id : null;

      var query = _supabase.from('products').select('id, name_fr, ref_code, reference, stock(*)');
      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }
      final data = await query.eq('is_active', true).order('name_fr');
      
      if (mounted) {
        setState(() {
          _products = data;
          _isLoading = false;
        });
        _filterProducts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Map<String, dynamic>? _getParsedStock(dynamic stockData) {
    if (stockData == null) return null;
    if (stockData is List && stockData.isNotEmpty) {
      return stockData[0] as Map<String, dynamic>?;
    } else if (stockData is Map) {
      return Map<String, dynamic>.from(stockData);
    }
    return null;
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredProducts = _products.where((p) {
        final name = (p['name_fr'] ?? '').toString().toLowerCase();
        final ref = (p['ref_code'] ?? '').toString().toLowerCase();
        final reference = (p['reference'] ?? '').toString().toLowerCase();
        final matchesSearch = name.contains(query) || ref.contains(query) || reference.contains(query);

        if (!matchesSearch) return false;

        if (_filterMode == 'low') {
          final stock = _getParsedStock(p['stock']);
          final qtyDetail = (stock?['qty_detail'] as num?)?.toDouble() ?? 0.0;
          final threshold = (stock?['alert_threshold'] as num?)?.toDouble() ?? 5.0;
          return qtyDetail <= threshold;
        }

        return true;
      }).toList();
    });
  }

  void _onProductSelected(Map<String, dynamic>? product) {
    setState(() {
      _selectedProduct = product;
      if (product != null) {
        final stock = _getParsedStock(product['stock']);
        if (stock != null) {
          _superGrosController.text = (stock['qty_super_gros'] ?? 0).toString();
          _grosController.text = (stock['qty_gros'] ?? 0).toString();
          _detailController.text = (stock['qty_detail'] ?? 0).toString();
          _alertThresholdController.text = (stock['alert_threshold'] ?? 5).toString();
        } else {
          _superGrosController.text = '0';
          _grosController.text = '0';
          _detailController.text = '0';
          _alertThresholdController.text = '5';
        }
      }
    });
  }

  Future<void> _saveStock() async {
    if (_selectedProduct == null) return;
    
    setState(() => _isLoading = true);
    try {
      final productId = _selectedProduct!['id'];
      
      final updates = {
        'qty_super_gros': double.tryParse(_superGrosController.text) ?? 0,
        'qty_gros': double.tryParse(_grosController.text) ?? 0,
        'qty_detail': double.tryParse(_detailController.text) ?? 0,
        'alert_threshold': double.tryParse(_alertThresholdController.text) ?? 5,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final existingStock = await _supabase.from('stock').select('id').eq('product_id', productId).maybeSingle();
      
      if (existingStock != null) {
        await _supabase.from('stock').update(updates).eq('product_id', productId);
      } else {
        updates['product_id'] = productId;
        await _supabase.from('stock').insert(updates);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated successfully!'), backgroundColor: Colors.green),
        );
        _fetchProducts(); // Refresh data
        _selectedProduct = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating stock: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canManageProducts.key,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Stock Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF203A43),
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
                    // Top controls bar
                    Row(
                      children: [
                        // Search Bar
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search products by name or reference...',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            ),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                            onChanged: (_) => _filterProducts(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Filter Mode Chips
                        ChoiceChip(
                          label: const Text('All Products'),
                          selected: _filterMode == 'all',
                          selectedColor: const Color(0xFF203A43),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _filterMode == 'all' ? Colors.white : const Color(0xFF475569),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _filterMode = 'all';
                                _filterProducts();
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Low Stock'),
                          selected: _filterMode == 'low',
                          selectedColor: const Color(0xFFB91C1C),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _filterMode == 'low' ? Colors.white : const Color(0xFF475569),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _filterMode = 'low';
                                _filterProducts();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Table Header/Card
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _filteredProducts.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  itemCount: _filteredProducts.length,
                                  separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                                  itemBuilder: (context, index) {
                                    final p = _filteredProducts[index];
                                    final stock = _getParsedStock(p['stock']);
                                    final qtySuperGros = (stock?['qty_super_gros'] as num?)?.toDouble() ?? 0.0;
                                    final qtyGros = (stock?['qty_gros'] as num?)?.toDouble() ?? 0.0;
                                    final qtyDetail = (stock?['qty_detail'] as num?)?.toDouble() ?? 0.0;
                                    final threshold = (stock?['alert_threshold'] as num?)?.toDouble() ?? 5.0;

                                    return _buildProductRow(p, qtySuperGros, qtyGros, qtyDetail, threshold);
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'No products found matching filters',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> product, double superGros, double gros, double detail, double threshold) {
    final isOutOfStock = detail <= 0;
    final isLowStock = detail <= threshold;

    Color statusColor = const Color(0xFF047857);
    String statusText = 'In Stock';
    Color statusBg = const Color(0xFFECFDF5);
    Color statusBorder = const Color(0xFFA7F3D0);

    if (isOutOfStock) {
      statusColor = const Color(0xFFB91C1C);
      statusText = 'Out of Stock';
      statusBg = const Color(0xFFFEE2E2);
      statusBorder = const Color(0xFFFCA5A5);
    } else if (isLowStock) {
      statusColor = const Color(0xFFD97706);
      statusText = 'Low Stock';
      statusBg = const Color(0xFFFEF3C7);
      statusBorder = const Color(0xFFFDE68A);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name_fr'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (product['reference'] != null && product['reference'].toString().isNotEmpty)
                      'Ref: ${product['reference']}',
                    if (product['ref_code'] != null && product['ref_code'].toString().isNotEmpty)
                      'Code: ${product['ref_code']}',
                  ].join(' • '),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Super Gros', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${superGros.toInt()} units',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gros', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${gros.toInt()} units',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Détail', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${detail.toInt()} units',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOutOfStock ? const Color(0xFFB91C1C) : (isLowStock ? const Color(0xFFD97706) : const Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alert Limit', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${threshold.toInt()} units',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF203A43)),
            onPressed: () => _showEditStockDialog(product),
            tooltip: 'Adjust Stock',
          ),
        ],
      ),
    );
  }

  void _showEditStockDialog(Map<String, dynamic> product) {
    _onProductSelected(product);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF203A43).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_road_outlined,
                  color: Color(0xFF203A43),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name_fr'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Ref: ${product['reference'] ?? product['ref_code'] ?? 'No Ref'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupStockField('Super Gros Stock', _superGrosController, Colors.blue),
                const SizedBox(height: 12),
                _buildPopupStockField('Gros Stock', _grosController, Colors.purple),
                const SizedBox(height: 12),
                _buildPopupStockField('Détail Stock', _detailController, Colors.orange),
                const SizedBox(height: 12),
                _buildPopupStockField('Alert Threshold', _alertThresholdController, Colors.red),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _selectedProduct = null);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _saveStock();
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopupStockField(String label, TextEditingController controller, Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              onPressed: () {
                double current = double.tryParse(controller.text) ?? 0;
                if (current > 0) controller.text = (current - 1).toString();
              },
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.grey.shade400,
            ),
            Expanded(
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    borderSide: BorderSide(color: themeColor, width: 2),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                double current = double.tryParse(controller.text) ?? 0;
                controller.text = (current + 1).toString();
              },
              icon: const Icon(Icons.add_circle_outline),
              color: themeColor,
            ),
          ],
        ),
      ],
    );
  }
}
