import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canViewAllSales.key,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historique des Documents',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2A32),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Recherchez et affichez vos factures, bons de livraison et tickets de caisse',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Rechercher par numéro, client ou type...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        onChanged: _filterSales,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Documents List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF203A43),
                        ),
                      )
                    : _filteredSales.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Aucun document trouvé',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredSales.length,
                            itemBuilder: (context, index) {
                              final sale = _filteredSales[index];
                              return _DocumentCard(
                                sale: sale,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DocumentViewerPage(
                                        saleId: sale['id'],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Document Card Widget ─────────────────────────────────────────────

class _DocumentCard extends StatefulWidget {
  final Map<String, dynamic> sale;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.sale,
    required this.onTap,
  });

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
  bool _isHovered = false;

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString);
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatSaleType(String type) {
    switch (type) {
      case 'detail':
        return 'Détail';
      case 'gros':
        return 'Gros';
      case 'bon_livraison':
        return 'Bon de Livraison';
      case 'bon_commande':
        return 'Bon de Commande';
      case 'gouvernement':
        return 'Gouvernement';
      default:
        return type;
    }
  }

  Color _getBadgeColor(String type) {
    switch (type) {
      case 'detail':
        return const Color(0xFF3B82F6);
      case 'gros':
        return const Color(0xFF8B5CF6);
      case 'bon_livraison':
        return const Color(0xFFF59E0B);
      case 'bon_commande':
        return const Color(0xFF0D9488);
      case 'gouvernement':
        return const Color(0xFFE11D48);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.sale['clients']?['name'] ?? 'Client Standard (Détail)';
    final totalTtc = (widget.sale['total_ttc'] as num?)?.toDouble() ?? 0.0;
    final typeColor = _getBadgeColor(widget.sale['sale_type']);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.03),
                blurRadius: _isHovered ? 16 : 10,
                offset: Offset(0, _isHovered ? 8 : 5),
              ),
            ],
            border: Border.all(
              color: _isHovered
                  ? typeColor.withValues(alpha: 0.2)
                  : Colors.grey.shade100,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    color: typeColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: typeColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      widget.sale['sale_number'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: typeColor.withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _formatSaleType(widget.sale['sale_type']),
                                        style: TextStyle(
                                          color: typeColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      clientName,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDate(widget.sale['created_at']),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${totalTtc.toStringAsFixed(2)} DZD',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: Color(0xFFEF4444),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PDF Invoiced',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
      ),
    );
  }
}
