import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/permission_guard.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _products = [];
  Map<String, dynamic>? _selectedProduct;

  final _superGrosController = TextEditingController();
  final _grosController = TextEditingController();
  final _detailController = TextEditingController();
  final _alertThresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await _supabase
          .from('products')
          .select('id, name_fr, ref_code, stock(*)')
          .eq('is_active', true)
          .order('name_fr');
      
      if (mounted) {
        setState(() {
          _products = data;
          _isLoading = false;
        });
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

  void _onProductSelected(Map<String, dynamic>? product) {
    setState(() {
      _selectedProduct = product;
      if (product != null && product['stock'] != null && product['stock'].isNotEmpty) {
        final stock = product['stock'][0];
        _superGrosController.text = stock['qty_super_gros'].toString();
        _grosController.text = stock['qty_gros'].toString();
        _detailController.text = stock['qty_detail'].toString();
        _alertThresholdController.text = stock['alert_threshold'].toString();
      } else {
        _superGrosController.text = '0';
        _grosController.text = '0';
        _detailController.text = '0';
        _alertThresholdController.text = '5';
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
      requiredPermission: 'can_manage_products',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stock Management'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF203A43),
          elevation: 0,
        ),
        backgroundColor: const Color(0xFFF8F9FA),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: InputDecoration(
                        labelText: 'Select Product',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedProduct,
                      items: _products.map((p) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: p,
                          child: Text('${p['ref_code'] ?? 'No Ref'} - ${p['name_fr']}'),
                        );
                      }).toList(),
                      onChanged: _onProductSelected,
                    ),
                    const SizedBox(height: 24),
                    if (_selectedProduct != null) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildStockCard('Super Gros', _superGrosController, Colors.blue.shade50),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStockCard('Gros', _grosController, Colors.purple.shade50),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStockCard('Détail', _detailController, Colors.orange.shade50),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _alertThresholdController,
                          decoration: InputDecoration(
                            labelText: 'Alert Threshold',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _saveStock,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Stock Adjustments'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF203A43),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Please select a product to manage stock.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStockCard(String title, TextEditingController controller, Color bgColor) {
    return Card(
      color: bgColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    double current = double.tryParse(controller.text) ?? 0;
                    if (current > 0) controller.text = (current - 1).toString();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    double current = double.tryParse(controller.text) ?? 0;
                    controller.text = (current + 1).toString();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
