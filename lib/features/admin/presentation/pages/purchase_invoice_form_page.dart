import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/permission_guard.dart';
import '../../../../core/constants/permissions_constants.dart';
import '../../../store/presentation/bloc/store_bloc.dart';
import '../bloc/suppliers/suppliers_bloc.dart';
import '../bloc/suppliers/suppliers_event.dart';
import '../bloc/suppliers/suppliers_state.dart';

class PurchaseInvoiceFormPage extends StatefulWidget {
  const PurchaseInvoiceFormPage({Key? key}) : super(key: key);

  @override
  State<PurchaseInvoiceFormPage> createState() => _PurchaseInvoiceFormPageState();
}

class _PurchaseInvoiceFormPageState extends State<PurchaseInvoiceFormPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  
  String? _selectedSupplierId;
  String _invoiceNumber = '';
  final TextEditingController _notesController = TextEditingController();

  // List of items in the invoice
  final List<_InvoiceItem> _items = [];

  @override
  void initState() {
    super.initState();
    _invoiceNumber = 'PI-${DateTime.now().millisecondsSinceEpoch}';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final storeId = context.read<StoreBloc>().currentStoreId;
      if (storeId == null) return;

      // Fetch suppliers
      final suppliersRes = await _supabase
          .from('suppliers')
          .select('id, name')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('name');
          
      // Fetch products
      final productsRes = await _supabase
          .from('products')
          .select('id, name_fr')
          .eq('store_id', storeId)
          .order('name_fr');

      if (mounted) {
        setState(() {
          _suppliers = List<Map<String, dynamic>>.from(suppliersRes);
          _products = List<Map<String, dynamic>>.from(productsRes);
          if (_items.isEmpty) {
            _items.add(_InvoiceItem(UniqueKey())); // Start with one empty line
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateTotals() {
    for (var item in _items) {
      final qty = double.tryParse(item.qtyController.text) ?? 0;
      final unitCost = double.tryParse(item.costController.text) ?? 0;
      item.totalCost = qty * unitCost;
    }
    setState(() {}); // Trigger rebuild to update totals
  }

  double get _grandTotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  void _submitInvoice() {
    if (_formKey.currentState!.validate()) {
      if (_selectedSupplierId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier')));
        return;
      }
      
      final validItems = _items.where((i) => i.selectedProductId != null && (double.tryParse(i.qtyController.text) ?? 0) > 0).toList();
      if (validItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one valid item')));
        return;
      }

      final storeId = context.read<StoreBloc>().currentStoreId;
      if (storeId == null) return;

      final invoiceData = {
        'invoice_number': _invoiceNumber,
        'supplier_id': _selectedSupplierId,
        'total_ht': _grandTotal,
        'tva_amount': 0, // Currently defaulting to 0 for purchases
        'timbre_fiscal': 0,
        'total_ttc': _grandTotal,
        'status': 'confirmed',
        'notes': _notesController.text.trim(),
        'worker_id': _supabase.auth.currentUser?.id,
      };

      final itemsData = validItems.map((item) {
        final qty = double.parse(item.qtyController.text);
        final unitCost = double.parse(item.costController.text);
        return {
          'product_id': item.selectedProductId,
          'quantity': qty,
          'unit_price_ht': unitCost,
          'tva_rate': 0,
          'unit_price_ttc': unitCost,
          'total_ht': qty * unitCost,
          'total_ttc': qty * unitCost,
        };
      }).toList();

      context.read<SuppliersBloc>().add(CreatePurchaseInvoice(
        invoiceData: invoiceData,
        items: itemsData,
        storeId: storeId,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SuppliersBloc, SuppliersState>(
      listener: (context, state) {
        if (state is SupplierOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          context.pop();
        } else if (state is SuppliersError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${state.message}')));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('New Purchase Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF203A43),
          elevation: 0,
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Items
                      Expanded(
                        flex: 7,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              // Header
                              Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Product', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 1, child: Text('Quantity', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 1, child: Text('Unit Cost', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 1, child: Text('Total', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 40), // For delete icon
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _items.length,
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: DropdownButtonFormField<String>(
                                              value: item.selectedProductId,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              items: _products.map((p) => DropdownMenuItem<String>(
                                                value: p['id'],
                                                child: Text(p['name_fr']),
                                              )).toList(),
                                              onChanged: (val) {
                                                setState(() => item.selectedProductId = val);
                                              },
                                              validator: (val) => val == null ? 'Required' : null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: TextFormField(
                                              controller: item.qtyController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                              onChanged: (_) => _calculateTotals(),
                                              validator: (val) => (double.tryParse(val ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: TextFormField(
                                              controller: item.costController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                              onChanged: (_) => _calculateTotals(),
                                              validator: (val) => (double.tryParse(val ?? '') ?? 0) < 0 ? 'Invalid' : null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              item.totalCost.toStringAsFixed(2),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              onPressed: () {
                                                setState(() {
                                                  _items.removeAt(index);
                                                  _calculateTotals();
                                                });
                                              },
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() => _items.add(_InvoiceItem(UniqueKey())));
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Product Row'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Summary
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              TextFormField(
                                initialValue: _invoiceNumber,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Invoice Number',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Color(0xFFF1F5F9),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedSupplierId,
                                decoration: const InputDecoration(labelText: 'Supplier *', border: OutlineInputBorder()),
                                items: _suppliers.map((s) => DropdownMenuItem<String>(
                                  value: s['id'],
                                  child: Text(s['name']),
                                )).toList(),
                                onChanged: (val) => setState(() => _selectedSupplierId = val),
                                validator: (val) => val == null ? 'Please select a supplier' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                                maxLines: 3,
                              ),
                              const Spacer(),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Grand Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('${_grandTotal.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final state = context.read<SuppliersBloc>().state;
                                    if (state is SuppliersLoading) return;
                                    _submitInvoice();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF203A43),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: BlocBuilder<SuppliersBloc, SuppliersState>(
                                    builder: (context, state) {
                                      if (state is SuppliersLoading) {
                                        return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                                      }
                                      return const Text('Confirm Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
                                    },
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _InvoiceItem {
  final Key key;
  String? selectedProductId;
  TextEditingController qtyController = TextEditingController(text: '1');
  TextEditingController costController = TextEditingController(text: '0');
  double totalCost = 0.0;

  _InvoiceItem(this.key);
}
