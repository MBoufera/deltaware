import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../store/presentation/bloc/store_state.dart';

// Represents a row in the data table
class InventoryItem {
  String name;
  int quantity;
  double purchasePrice;
  double marginPercentage;
  double tvaPercentage;

  InventoryItem({
    required this.name,
    required this.quantity,
    required this.purchasePrice,
    this.marginPercentage = 20.0,
    this.tvaPercentage = 19.0,
  });

  // Dynamic calculations
  double get wholesalePrice =>
      purchasePrice + (purchasePrice * marginPercentage / 100);
  double get retailPrice => wholesalePrice * 1.30;
}

class SmartBatchPage extends StatefulWidget {
  const SmartBatchPage({super.key});

  @override
  State<SmartBatchPage> createState() => _SmartBatchPageState();
}

class _SmartBatchPageState extends State<SmartBatchPage> {
  final List<InventoryItem> _items = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Rapid Entry Controllers & Focus Nodes
  final _quickNameController = TextEditingController();
  final _quickQuantityController = TextEditingController(text: '1');
  final _quickPriceController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  // NOTE: Key hidden for GitHub
  final String _geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY');

  @override
  void dispose() {
    _quickNameController.dispose();
    _quickQuantityController.dispose();
    _quickPriceController.dispose();
    _nameFocusNode.dispose();
    _quantityFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scanInvoice() async {
    if (_geminiApiKey == 'YOUR_GEMINI_API_KEY' || _geminiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide your Gemini API Key in the code first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isLoading = true);

      final imageBytes = await image.readAsBytes();

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _geminiApiKey,
      );

      final prompt = TextPart(
        'Extract all the line items from this invoice/receipt. '
        'Return ONLY a raw JSON array (no markdown block, just the raw JSON brackets). '
        'Each object in the array must have exactly three keys: '
        '"name" (string), "quantity" (integer), and "purchase_price" (number). '
        'Do not include any other text.',
      );

      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      if (response.text != null) {
        String jsonString = response.text!.trim();
        // Remove markdown formatting if Gemini still includes it
        if (jsonString.startsWith('```json')) {
          jsonString = jsonString
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
        }

        final List<dynamic> jsonList = jsonDecode(jsonString);

        setState(() {
          for (var item in jsonList) {
            _items.add(
              InventoryItem(
                name: item['name'] ?? 'Unknown Item',
                quantity: (item['quantity'] ?? 1).toInt(),
                purchasePrice: (item['purchase_price'] ?? 0.0).toDouble(),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addRapidItem() {
    final name = _quickNameController.text.trim();
    final quantity = int.tryParse(_quickQuantityController.text) ?? 1;
    final price = double.tryParse(_quickPriceController.text) ?? 0.0;

    if (name.isNotEmpty && price > 0) {
      setState(() {
        _items.insert(0, InventoryItem(
          name: name,
          quantity: quantity,
          purchasePrice: price,
        ));
      });
      // Clear inputs except quantity
      _quickNameController.clear();
      _quickPriceController.clear();
      _quickQuantityController.text = '1';
      // Snap focus back to name field for next scan/type
      FocusScope.of(context).requestFocus(_nameFocusNode);
    }
  }

  Future<void> _saveBatch() async {
    if (_items.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final storeState = context.read<StoreBloc>().state;
      final storeId = storeState is StoresLoaded ? storeState.selectedStore?.id : null;

      final categoryName = 'products.uncategorized'.tr();
      var categoryQuery = supabase.from('categories').select('id').eq('name_fr', categoryName);
      if (storeId != null) {
        categoryQuery = categoryQuery.eq('store_id', storeId);
      }
      var categoryResponse = await categoryQuery.maybeSingle();

      String categoryId;
      if (categoryResponse == null) {
        final insertData = <String, dynamic>{'name_fr': categoryName};
        if (storeId != null) insertData['store_id'] = storeId;
        final newCat = await supabase.from('categories').insert(insertData).select('id').single();
        categoryId = newCat['id'];
      } else {
        categoryId = categoryResponse['id'];
      }

      for (var item in _items) {
        final insertProductData = <String, dynamic>{
          'name_fr': item.name,
          'category_id': categoryId,
        };
        if (storeId != null) insertProductData['store_id'] = storeId;
        final productResponse = await supabase.from('products').insert(insertProductData).select('id').single();
        
        final productId = productResponse['id'];
        
        await supabase.from('product_pricing').insert({
          'product_id': productId,
          'prix_achat_super_gros': item.purchasePrice,
          'marge_gros_percent': item.marginPercentage,
          'marge_detail_percent': (1.30 - 1.0) * 100,
          'tva_rate': item.tvaPercentage,
        });
        
        await supabase.from('stock').insert({
          'product_id': productId,
          'qty_detail': item.quantity,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('smart_batch.success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _items.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to DB: $e'),
            backgroundColor: Colors.red,
          ),
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
        backgroundColor: Colors.transparent,
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'smart_batch.title'.tr(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF203A43),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _scanInvoice,
                    icon: const Icon(Icons.document_scanner),
                    label: Text('smart_batch.scan_invoice'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'smart_batch.subtitle'.tr(),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Rapid Entry Quick Add Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _quickNameController,
                        focusNode: _nameFocusNode,
                        decoration: InputDecoration(
                          hintText: 'smart_batch.item_name'.tr(),
                          prefixIcon: Icon(Icons.qr_code_scanner, color: Colors.blue.shade400, size: 20),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_quantityFocusNode),
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.grey.shade200),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _quickQuantityController,
                        focusNode: _quantityFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'smart_batch.qty'.tr(),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_priceFocusNode),
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.grey.shade200),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _quickPriceController,
                        focusNode: _priceFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'smart_batch.unit_price'.tr(),
                          prefixIcon: Icon(Icons.attach_money, color: Colors.green.shade600, size: 20),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _addRapidItem(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addRapidItem,
                        tooltip: 'Add to Batch (Enter)',
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'smart_batch.no_items'.tr(),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) => Colors.grey.shade50,
                                    ),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_name'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_qty'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_purchase'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_margin'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_wholesale'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_retail'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_tva'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'smart_batch.col_actions'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                rows: _items.map((item) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(item.name)),
                                      DataCell(Text(item.quantity.toString())),
                                      DataCell(
                                        Text(
                                          '${item.purchasePrice.toStringAsFixed(2)} DZD',
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            initialValue: item.marginPercentage
                                                .toString(),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              setState(() {
                                                item.marginPercentage =
                                                    double.tryParse(val) ?? 0.0;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${item.wholesalePrice.toStringAsFixed(2)} DZD',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${item.retailPrice.toStringAsFixed(2)} DZD',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            initialValue: item.tvaPercentage
                                                .toString(),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              setState(() {
                                                item.tvaPercentage =
                                                    double.tryParse(val) ?? 0.0;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _items.remove(item);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Total Items: ${_items.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 24),
                              ElevatedButton.icon(
                                onPressed: _saveBatch,
                                icon: const Icon(Icons.save),
                                label: Text('smart_batch.save_batch'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
