import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/suppliers/suppliers_bloc.dart';
import '../bloc/suppliers/suppliers_event.dart';
import '../../../store/presentation/bloc/store_bloc.dart';

class SupplierFicheTierPage extends StatefulWidget {
  final Map<String, dynamic> supplier;
  const SupplierFicheTierPage({Key? key, required this.supplier}) : super(key: key);

  @override
  State<SupplierFicheTierPage> createState() => _SupplierFicheTierPageState();
}

class _SupplierFicheTierPageState extends State<SupplierFicheTierPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  double _currentDebt = 0;
  DateTime? _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadFicheTier();
  }

  Future<void> _loadFicheTier() async {
    setState(() => _isLoading = true);
    try {
      final supplierId = widget.supplier['supplier_id'] ?? widget.supplier['id'];
      
      // 1. Fetch Payments (Purchases will be added later when implemented)
      final paymentsRes = await _supabase
          .from('supplier_payments')
          .select('id, amount, payment_method, created_at, reference')
          .eq('supplier_id', supplierId);

      List<Map<String, dynamic>> transactions = [];

      // 2. Fetch Purchases
      final purchasesRes = await _supabase
          .from('purchase_invoices')
          .select('id, invoice_number, total_ttc, created_at')
          .eq('supplier_id', supplierId)
          .eq('status', 'confirmed');

      for (var p in paymentsRes) {
        final method = p['payment_method'] == 'cash' ? 'Cash' : 
                       p['payment_method'] == 'bank_transfer' ? 'Bank Transfer' : 'Check';
        transactions.add({
          'id': p['id'],
          'type': 'payment',
          'method': method,
          'raw_ref': p['reference'] ?? '',
          'date': DateTime.parse(p['created_at']),
          'ref': 'Payment ($method) ${p['reference'] ?? ''}',
          'debit': 0.0,
          'credit': double.tryParse(p['amount'].toString()) ?? 0.0,
        });
      }

      for (var p in purchasesRes) {
        transactions.add({
          'id': p['id'],
          'type': 'purchase',
          'date': DateTime.parse(p['created_at']),
          'ref': 'Invoice ${p['invoice_number']}',
          'debit': double.tryParse(p['total_ttc'].toString()) ?? 0.0,
          'credit': 0.0,
        });
      }

      // Sort chronological (oldest first) to calculate running balance
      transactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      double runningBalance = 0;
      for (var t in transactions) {
        runningBalance += (t['debit'] as double); // Purchases increase what we owe
        runningBalance -= (t['credit'] as double); // Payments decrease what we owe
        t['running_balance'] = runningBalance;
      }

      setState(() {
        // Reverse so newest is at the top
        _transactions = transactions.reversed.toList();
        _currentDebt = runningBalance;
      });
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPaymentDetails(Map<String, dynamic> payment, DateTime paymentDate) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT RECEIPT',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reference: ${payment['raw_ref'].toString().isNotEmpty ? payment['raw_ref'] : 'N/A'}',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(paymentDate)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Supplier Info
              Text(
                'Received From:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 4),
              Text(
                widget.supplier['name'] ?? 'Unknown Supplier',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              
              // Payment Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Method:', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  Text(payment['method'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount Paid:', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  Text('${(payment['credit'] as double).toStringAsFixed(2)} DZD', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ],
              ),
              const SizedBox(height: 32),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Print / PDF generation coming soon!')));
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print / PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(String invoiceId, String invoiceRef, DateTime invoiceDate) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Container(
          width: 800, // Wide professional look
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVOICE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        invoiceRef,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(invoiceDate)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long, size: 48, color: Colors.blue.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Supplier Info
              Text(
                'Billed To:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 4),
              Text(
                widget.supplier['name'] ?? 'Unknown Supplier',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (widget.supplier['phone'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.supplier['phone'],
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              
              // Items Table
              Flexible(
                child: FutureBuilder(
                  future: _supabase
                      .from('purchase_invoice_items')
                      .select('''
                        quantity,
                        unit_price_ttc,
                        total_ttc,
                        products (
                          name_fr
                        )
                      ''')
                      .eq('invoice_id', invoiceId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      );
                    }
      
                    final res = snapshot.data as List<dynamic>? ?? [];
                    if (res.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('No items found in this invoice.'),
                      );
                    }
                    
                    double invoiceTotal = 0;
                    for (var item in res) {
                      invoiceTotal += double.tryParse(item['total_ttc'].toString()) ?? 0;
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade50),
                                columns: const [
                                  DataColumn(label: Text('Product / Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                  DataColumn(label: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                  DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                ],
                                rows: res.map((item) {
                                  final productName = item['products'] != null ? item['products']['name_fr'] : 'Unknown';
                                  final qty = double.tryParse(item['quantity'].toString()) ?? 0;
                                  final price = double.tryParse(item['unit_price_ttc'].toString()) ?? 0;
                                  final total = double.tryParse(item['total_ttc'].toString()) ?? 0;
                                  
                                  return DataRow(cells: [
                                    DataCell(Text(productName.toString(), style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text(qty.toString())),
                                    DataCell(Text(price.toStringAsFixed(2))),
                                    DataCell(Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Totals Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 24),
                                  Text('${invoiceTotal.toStringAsFixed(2)} DZD', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Print / PDF generation coming soon!')));
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print / PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog() {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    String paymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Payment to Supplier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (DZD)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer (Versement)')),
                  DropdownMenuItem(value: 'check', child: Text('Check')),
                ],
                onChanged: (v) => paymentMethod = v!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: refController,
                decoration: const InputDecoration(labelText: 'Reference / Cheque Number', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;
                
                final storeId = context.read<StoreBloc>().currentStoreId;
                if (storeId == null) return;

                context.read<SuppliersBloc>().add(AddSupplierPayment(
                  supplierId: widget.supplier['supplier_id'] ?? widget.supplier['id'],
                  storeId: storeId,
                  amount: amount,
                  paymentMethod: paymentMethod,
                  reference: refController.text.trim(),
                ));
                
                Navigator.pop(ctx);
                _loadFicheTier(); // Reload the ledger
              },
              child: const Text('Add Payment'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedTransactions = _transactions.where((t) {
      if (_selectedDate == null) return true;
      final d = t['date'] as DateTime;
      return d.year == _selectedDate!.year && 
             d.month == _selectedDate!.month && 
             d.day == _selectedDate!.day;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Fiche Tier: ${widget.supplier['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF203A43),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton.icon(
              onPressed: _showAddPaymentDialog,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Payment', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Debt Balance', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(
                              '${_currentDebt.toStringAsFixed(2)} DZD',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _currentDebt > 0 ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.account_balance_wallet, size: 48, color: Colors.grey.shade300),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Date:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_selectedDate == null ? 'All Time' : DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _selectedDate = d);
                        },
                      ),
                      if (_selectedDate != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            tooltip: 'Clear filter (Show All Time)',
                            onPressed: () => setState(() => _selectedDate = null),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Debit (Purchase)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Credit (Payment)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: displayedTransactions.map((t) {
                              final date = (t['date'] as DateTime).toLocal();
                              final debit = double.tryParse(t['debit'].toString()) ?? 0;
                              final credit = double.tryParse(t['credit'].toString()) ?? 0;
                              final balance = t['running_balance'] as double;

                              return DataRow(
                                onSelectChanged: (selected) {
                                  if (t['type'] == 'purchase') {
                                    _showInvoiceDetails(t['id'].toString(), t['ref'].toString(), date);
                                  } else if (t['type'] == 'payment') {
                                    _showPaymentDetails(t, date);
                                  }
                                },
                                cells: [
                                DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(date), style: TextStyle(color: Colors.grey.shade600))),
                                DataCell(Text(t['ref'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: debit > 0 ? Colors.red.shade700 : Colors.green.shade700))),
                                DataCell(Text(debit > 0 ? debit.toStringAsFixed(2) : '-', style: TextStyle(color: debit > 0 ? Colors.red.shade700 : Colors.grey.shade400))),
                                DataCell(Text(credit > 0 ? credit.toStringAsFixed(2) : '-', style: TextStyle(color: credit > 0 ? Colors.green.shade700 : Colors.grey.shade400))),
                                DataCell(Text(balance.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
