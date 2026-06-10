import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/permission_guard.dart';
import 'document_viewer_page.dart';

class DocumentHistoryPage extends StatefulWidget {
  const DocumentHistoryPage({super.key});

  @override
  State<DocumentHistoryPage> createState() => _DocumentHistoryPageState();
}

class _DocumentHistoryPageState extends State<DocumentHistoryPage> {
  final _supabase = Supabase.instance.client;
  
  List<dynamic> _sales = [];
  List<dynamic> _filteredSales = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _fetchSalesHistory();
  }

  Future<void> _fetchSalesHistory() async {
    try {
      final data = await _supabase
          .from('sales')
          .select('id, sale_number, sale_type, total_ttc, created_at, clients(name)')
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _sales = data;
          _filteredSales = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _filterSales(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredSales = _sales.where((sale) {
        final saleNum = (sale['sale_number'] ?? '').toLowerCase();
        final clientName = (sale['clients']?['name'] ?? '').toLowerCase();
        final saleType = (sale['sale_type'] ?? '').toLowerCase();
        
        return saleNum.contains(_searchQuery) || 
               clientName.contains(_searchQuery) || 
               saleType.contains(_searchQuery);
      }).toList();
    });
  }

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString);
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatSaleType(String type) {
    switch (type) {
      case 'detail': return 'Détail';
      case 'gros': return 'Gros';
      case 'bon_livraison': return 'Bon de Livraison';
      case 'bon_commande': return 'Bon de Commande';
      case 'gouvernement': return 'Gouvernement';
      default: return type;
    }
  }

  Color _getBadgeColor(String type) {
    switch (type) {
      case 'detail': return Colors.blue;
      case 'gros': return Colors.purple;
      case 'bon_livraison': return Colors.orange;
      case 'bon_commande': return Colors.teal;
      case 'gouvernement': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: 'can_view_all_sales',
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          title: const Text('Historique des Documents'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF203A43),
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher par numéro, client ou type...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: _filterSales,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSales.isEmpty
                      ? const Center(child: Text('Aucun document trouvé'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSales.length,
                          itemBuilder: (context, index) {
                            final sale = _filteredSales[index];
                            final clientName = sale['clients']?['name'] ?? 'Client Standard (Détail)';
                            final totalTtc = (sale['total_ttc'] as num?)?.toDouble() ?? 0.0;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: _getBadgeColor(sale['sale_type']).withAlpha(50),
                                  child: Icon(Icons.receipt_long, color: _getBadgeColor(sale['sale_type'])),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      sale['sale_number'] ?? 'N/A',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getBadgeColor(sale['sale_type']),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatSaleType(sale['sale_type']),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Client: $clientName'),
                                      const SizedBox(height: 4),
                                      Text('Date: ${_formatDate(sale['created_at'])}'),
                                    ],
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${totalTtc.toStringAsFixed(2)} DZD',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green),
                                    ),
                                    const SizedBox(height: 8),
                                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DocumentViewerPage(saleId: sale['id']),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
