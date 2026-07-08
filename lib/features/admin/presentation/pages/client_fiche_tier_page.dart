import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ClientFicheTierPage extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientFicheTierPage({Key? key, required this.client}) : super(key: key);

  @override
  State<ClientFicheTierPage> createState() => _ClientFicheTierPageState();
}

class _ClientFicheTierPageState extends State<ClientFicheTierPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  double _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadFicheTier();
  }

  Future<void> _loadFicheTier() async {
    setState(() => _isLoading = true);
    try {
      final clientId = widget.client['client_id'];
      
      // 1. Fetch Sales
      final salesRes = await _supabase
          .from('sales')
          .select('id, sale_number, total_ttc, created_at')
          .eq('client_id', clientId)
          .eq('status', 'confirmed');
          
      // 2. Fetch Payments
      final paymentsRes = await _supabase
          .from('client_payments')
          .select('id, amount, payment_method, created_at, reference')
          .eq('client_id', clientId);

      List<Map<String, dynamic>> transactions = [];

      for (var s in salesRes) {
        transactions.add({
          'type': 'sale',
          'date': DateTime.parse(s['created_at']),
          'ref': s['sale_number'] ?? 'Sale',
          'debit': double.tryParse(s['total_ttc'].toString()) ?? 0.0,
          'credit': 0.0,
        });
      }

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

      // Sort chronological (oldest first) to calculate running balance
      transactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      double runningBalance = 0;
      for (var t in transactions) {
        runningBalance += (t['debit'] as double);
        runningBalance -= (t['credit'] as double);
        t['balance'] = runningBalance;
      }

      setState(() {
        // Reverse so newest is at the top
        _transactions = transactions.reversed.toList();
        _currentBalance = runningBalance;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading Fiche Tier: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddPaymentDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String method = 'cash';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Payment', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (DZD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'check', child: Text('Check')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => method = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Reference / Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) return;

                    Navigator.of(ctx).pop();
                    setState(() => _isLoading = true);

                    try {
                      await _supabase.from('client_payments').insert({
                        'client_id': widget.client['client_id'],
                        'store_id': widget.client['store_id'],
                        'amount': amount,
                        'payment_method': method,
                        'reference': notesController.text,
                      });
                      _loadFicheTier(); // Reload data
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding payment: $e')));
                      setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203A43)),
                  child: const Text('Save Payment', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Fiche Tier: ${widget.client['name']}', style: const TextStyle(color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF203A43),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _showAddPaymentDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF203A43)))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Debt Balance', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            Text(
                              '${_currentBalance.toStringAsFixed(2)} DZD',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.account_balance_wallet, size: 48, color: Colors.grey.shade300),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Ledger Table
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Debit (Sale)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Credit (Payment)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _transactions.map((t) {
                              final isSale = t['type'] == 'sale';
                              final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
                              return DataRow(
                                cells: [
                                  DataCell(Text(dateFormat.format(t['date']))),
                                  DataCell(Text(
                                    t['ref'], 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSale ? const Color(0xFF1E293B) : const Color(0xFF047857)
                                    )
                                  )),
                                  DataCell(Text(
                                    t['debit'] > 0 ? '${t['debit'].toStringAsFixed(2)}' : '-',
                                    style: const TextStyle(color: Color(0xFFB91C1C))
                                  )),
                                  DataCell(Text(
                                    t['credit'] > 0 ? '${t['credit'].toStringAsFixed(2)}' : '-',
                                    style: const TextStyle(color: Color(0xFF047857))
                                  )),
                                  DataCell(Text(
                                    '${t['balance'].toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)
                                  )),
                                ],
                              );
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
