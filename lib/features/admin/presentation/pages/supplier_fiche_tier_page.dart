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

  @override
  void initState() {
    super.initState();
    _loadFicheTier();
  }

  Future<void> _loadFicheTier() async {
    setState(() => _isLoading = true);
    try {
      final supplierId = widget.supplier['id'];
      
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
          'type': 'payment',
          'date': DateTime.parse(p['created_at']),
          'ref': 'Payment ($method) ${p['reference'] ?? ''}',
          'debit': 0.0,
          'credit': double.tryParse(p['amount'].toString()) ?? 0.0,
        });
      }

      for (var p in purchasesRes) {
        transactions.add({
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
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
                  supplierId: widget.supplier['id'],
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
                            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Debit (Purchase)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Credit (Payment)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _transactions.map((t) {
                              final date = DateTime.parse(t['date']).toLocal();
                              final debit = double.tryParse(t['debit'].toString()) ?? 0;
                              final credit = double.tryParse(t['credit'].toString()) ?? 0;
                              final balance = t['running_balance'] as double;

                              return DataRow(cells: [
                                DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(date), style: TextStyle(color: Colors.grey.shade600))),
                                DataCell(Text(t['reference'], style: TextStyle(fontWeight: FontWeight.w600, color: debit > 0 ? Colors.red.shade700 : Colors.green.shade700))),
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
