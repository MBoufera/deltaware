import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // NOTE: Key hidden for GitHub
  final String _geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY');

  Future<void> _scanInvoice() async {
    if (_geminiApiKey == 'YOUR_GEMINI_API_KEY' || _geminiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide your Gemini API Key in the code first!',
          ),
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

  Future<void> _saveBatch() async {
    if (_items.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      final batchData = _items
          .map(
            (item) => {
              'name': item.name,
              'quantity': item.quantity,
              'purchase_price': item.purchasePrice,
              'margin_percentage': item.marginPercentage,
              'wholesale_price': item.wholesalePrice,
              'retail_price': item.retailPrice,
              'tva_percentage': item.tvaPercentage,
            },
          )
          .toList();

      await supabase.from('inventory_items').insert(batchData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch successfully saved to database!'),
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
    return Scaffold(
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
                  const Text(
                    'Smart Invoice Scanner',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF203A43),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _scanInvoice,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Scan Invoice (AI)'),
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
                'Upload an invoice and the AI will automatically extract items and calculate your wholesale and retail margins.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

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
                          'No items scanned yet.',
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
                          color: Colors.black.withOpacity(0.05),
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
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Product Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Qty',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      "Prix d'Achat",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Marge %',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Prix de Gros',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Prix Détail',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'TVA %',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Actions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                label: const Text('Save Batch to Database'),
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
    );
  }
}
