import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/client_selection_dialog.dart';
import 'document_viewer_page.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  
  String _saleType = 'detail'; // detail, gros, bon_livraison, bon_commande, gouvernement
  final Map<String, int> _cart = {}; // product_id -> quantity
  bool _timbreFiscalEnabled = false;
  Map<String, dynamic>? _selectedClient;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await _supabase
          .from('products')
          .select('id, name_fr, ref_code, stock(qty_super_gros, qty_gros, qty_detail), product_pricing(prix_vente_gros_ht, prix_vente_detail_ht, tva_rate), categories(name_fr)')
          .eq('is_active', true);
      
      if (mounted) {
        setState(() {
          _products = data;
          _filteredProducts = List.from(data);
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

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _products.where((p) {
        final name = (p['name_fr'] ?? '').toLowerCase();
        final ref = (p['ref_code'] ?? '').toLowerCase();
        final q = query.toLowerCase();
        return name.contains(q) || ref.contains(q);
      }).toList();
    });
  }

  double _getPriceForType(Map<String, dynamic> product) {
    final pricing = product['product_pricing'];
    if (pricing == null) return 0.0;
    
    if (_saleType == 'detail') {
      return (pricing['prix_vente_detail_ht'] as num?)?.toDouble() ?? 0.0;
    } else {
      return (pricing['prix_vente_gros_ht'] as num?)?.toDouble() ?? 0.0;
    }
  }

  double _getTvaRate(Map<String, dynamic> product) {
    final pricing = product['product_pricing'];
    return (pricing?['tva_rate'] as num?)?.toDouble() ?? 19.0;
  }

  double _getStockForType(Map<String, dynamic> product) {
    final stock = product['stock'];
    if (stock == null) return 0.0;
    
    if (_saleType == 'detail') {
      return (stock['qty_detail'] as num?)?.toDouble() ?? 0.0;
    } else {
      return (stock['qty_gros'] as num?)?.toDouble() ?? 0.0;
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    final id = product['id'] as String;
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + 1;
    });
  }

  void _updateCartQty(String id, int delta) {
    setState(() {
      int newQty = (_cart[id] ?? 0) + delta;
      if (newQty <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = newQty;
      }
    });
  }

  // --- Calculations ---
  double get _totalHt {
    double total = 0;
    _cart.forEach((id, qty) {
      final p = _products.firstWhere((p) => p['id'] == id);
      total += _getPriceForType(p) * qty;
    });
    return total;
  }

  Map<double, double> get _tvaBreakdown {
    Map<double, double> breakdown = {};
    _cart.forEach((id, qty) {
      final p = _products.firstWhere((p) => p['id'] == id);
      double rate = _getTvaRate(p);
      double itemHt = _getPriceForType(p) * qty;
      double itemTva = itemHt * (rate / 100);
      breakdown[rate] = (breakdown[rate] ?? 0) + itemTva;
    });
    return breakdown;
  }

  double get _totalTva => _tvaBreakdown.values.fold(0, (a, b) => a + b);
  
  double get _subtotalTtc => _totalHt + _totalTva;
  
  double get _timbreFiscal => _timbreFiscalEnabled ? (_subtotalTtc * 0.01) : 0;
  
  double get _grandTotalTtc => _subtotalTtc + _timbreFiscal;

  // --- Layout ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Row(
        children: [
          // Left Pane: Products
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildProductGrid()),
              ],
            ),
          ),
          // Right Pane: Cart
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(-5, 0),
                  )
                ],
              ),
              child: _buildCart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ToggleButtons(
              isSelected: [
                _saleType == 'detail',
                _saleType == 'gros',
                _saleType == 'bon_livraison',
                _saleType == 'bon_commande',
                _saleType == 'gouvernement',
              ],
              onPressed: (index) {
                setState(() {
                  const types = ['detail', 'gros', 'bon_livraison', 'bon_commande', 'gouvernement'];
                  _saleType = types[index];
                });
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: const Color(0xFF203A43),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Détail')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Gros')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('BL')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('BC')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Gouvernement')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products by name or reference...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: _filterProducts,
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final p = _filteredProducts[index];
        final price = _getPriceForType(p);
        final stock = _getStockForType(p);
        
        return InkWell(
          onTap: () => _addToCart(p),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: const Icon(Icons.inventory_2, size: 48, color: Colors.blue),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name_fr'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Stock: $stock', style: TextStyle(color: stock > 0 ? Colors.green : Colors.red, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('${price.toStringAsFixed(2)} DZD', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF203A43), fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCart() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFF1A2A32),
          width: double.infinity,
          child: const Text(
            'Current Sale',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('Cart is empty', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final id = _cart.keys.elementAt(index);
                    final qty = _cart[id]!;
                    final p = _products.firstWhere((p) => p['id'] == id);
                    final price = _getPriceForType(p);
                    final total = price * qty;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['name_fr'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${price.toStringAsFixed(2)} DZD', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _updateCartQty(id, -1)),
                                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _updateCartQty(id, 1)),
                              ],
                            ),
                            SizedBox(
                              width: 80,
                              child: Text('${total.toStringAsFixed(2)} DZD', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildCartFooter(),
      ],
    );
  }

  Widget _buildCartFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Client:'),
              TextButton.icon(
                icon: const Icon(Icons.person_add),
                label: Text(_selectedClient != null ? _selectedClient!['name'] : 'Select Client'),
                onPressed: _showClientDialog,
              )
            ],
          ),
          SwitchListTile(
            title: const Text('Timbre Fiscal (1%)'),
            value: _timbreFiscalEnabled,
            onChanged: (v) => setState(() => _timbreFiscalEnabled = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          _buildSummaryRow('Total HT', _totalHt),
          ..._tvaBreakdown.entries.map((e) => _buildSummaryRow('TVA ${e.key}%', e.value)),
          if (_timbreFiscalEnabled) _buildSummaryRow('Timbre', _timbreFiscal),
          const Divider(thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL TTC', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text('${_grandTotalTtc.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : _submitSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CONFIRM SALE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text('${amount.toStringAsFixed(2)} DZD', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _showClientDialog() async {
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ClientSelectionDialog(saleType: _saleType),
    );

    if (client != null) {
      setState(() {
        _selectedClient = client;
      });
    }
  }

  Future<void> _submitSale() async {
    if (['bon_livraison', 'bon_commande', 'gros', 'gouvernement'].contains(_saleType) && _selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client is required for this sale type')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      
      List<Map<String, dynamic>> items = [];
      _cart.forEach((id, qty) {
        final p = _products.firstWhere((p) => p['id'] == id);
        final priceHt = _getPriceForType(p);
        final tvaRate = _getTvaRate(p);
        final itemTva = priceHt * (tvaRate / 100);
        final priceTtc = priceHt + itemTva;
        
        items.add({
          'product_id': id,
          'quantity': qty,
          'unit_price_ht': priceHt,
          'tva_rate': tvaRate,
          'unit_price_ttc': priceTtc,
          'total_ht': priceHt * qty,
          'total_ttc': priceTtc * qty,
          'discount_percent': 0,
        });
      });

      final payload = {
        'sale': {
          'sale_type': _saleType,
          'worker_id': user?.id,
          'client_id': _selectedClient?['id'],
          'total_ht': _totalHt,
          'tva_amount': _totalTva,
          'timbre_fiscal': _timbreFiscal,
          'total_ttc': _grandTotalTtc,
          'notes': 'POS Sale'
        },
        'items': items
      };

      final response = await _supabase.rpc('process_pos_sale', params: {'payload': payload});

      if (mounted) {
        setState(() {
          _cart.clear();
          _selectedClient = null;
          _isLoading = false;
        });
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sale Successful!'),
            content: Text('Sale Reference: ${response['sale_number']}\nTotal: ${_grandTotalTtc.toStringAsFixed(2)} DZD'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => DocumentViewerPage(saleId: response['sale_id']),
                  ));
                },
                child: const Text('Print Document'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('New Sale'),
              ),
            ],
          ),
        );
        
        _fetchProducts(); // Refresh stock
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transaction Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
