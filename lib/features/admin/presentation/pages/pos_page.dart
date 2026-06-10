import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sales/sales_bloc.dart';
import '../bloc/sales/sales_event.dart';
import '../bloc/sales/sales_state.dart';
import '../widgets/client_selection_dialog.dart';
import 'document_viewer_page.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(LoadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
          );
        } else if (state is SalesSuccess) {
          _showSuccessDialog(context, state);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        body: BlocBuilder<SalesBloc, SalesState>(
          builder: (context, state) {
            if (state is SalesInitial || state is SalesLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is SalesUpdated) {
              return Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        _buildTopBar(state),
                        Expanded(child: _buildProductGrid(state)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(-5, 0),
                          )
                        ],
                      ),
                      child: _buildCart(state),
                    ),
                  ),
                ],
              );
            }
            return const Center(child: Text('Unexpected State'));
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(SalesUpdated state) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ToggleButtons(
              isSelected: [
                state.saleType == 'detail',
                state.saleType == 'gros',
                state.saleType == 'bon_livraison',
                state.saleType == 'bon_commande',
                state.saleType == 'gouvernement',
              ],
              onPressed: (index) {
                const types = ['detail', 'gros', 'bon_livraison', 'bon_commande', 'gouvernement'];
                context.read<SalesBloc>().add(SelectSaleType(types[index]));
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
            onChanged: (query) => context.read<SalesBloc>().add(SearchProducts(query)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(SalesUpdated state) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: state.filteredProducts.length,
      itemBuilder: (context, index) {
        final p = state.filteredProducts[index];
        final price = _getPriceForType(p, state.saleType);
        final stock = _getStockForType(p, state.saleType);
        
        return InkWell(
          onTap: () => context.read<SalesBloc>().add(AddItemToCart(p)),
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

  Widget _buildCart(SalesUpdated state) {
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
          child: state.cart.isEmpty
              ? const Center(child: Text('Cart is empty', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.cart.length,
                  itemBuilder: (context, index) {
                    final id = state.cart.keys.elementAt(index);
                    final qty = state.cart[id]!;
                    final p = state.products.firstWhere((p) => p['id'] == id);
                    final price = _getPriceForType(p, state.saleType);
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
                                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, -1))),
                                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, 1))),
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
        _buildCartFooter(state),
      ],
    );
  }

  Widget _buildCartFooter(SalesUpdated state) {
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
                label: Text(state.selectedClient != null ? state.selectedClient!['name'] : 'Select Client'),
                onPressed: () => _showClientDialog(state.saleType),
              )
            ],
          ),
          SwitchListTile(
            title: const Text('Timbre Fiscal (1%)'),
            value: state.timbreFiscalEnabled,
            onChanged: (v) => context.read<SalesBloc>().add(ToggleTimbreFiscal(v)),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          _buildSummaryRow('Total HT', state.totalHt),
          ...state.tvaBreakdown.entries.map((e) => _buildSummaryRow('TVA ${e.key}%', e.value)),
          if (state.timbreFiscalEnabled) _buildSummaryRow('Timbre', state.timbreFiscal),
          const Divider(thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL TTC', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text('${state.grandTotalTtc.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: (state.cart.isEmpty || state is SalesSubmitting) 
                  ? null 
                  : () => context.read<SalesBloc>().add(SubmitSale()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: state is SalesSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('CONFIRM SALE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Future<void> _showClientDialog(String saleType) async {
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ClientSelectionDialog(saleType: saleType),
    );

    if (client != null && mounted) {
      context.read<SalesBloc>().add(SetClient(client));
    }
  }

  void _showSuccessDialog(BuildContext context, SalesSuccess state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale Successful!'),
        content: Text('Sale Reference: ${state.response['sale_number']}\nTotal: ${state.totalTtc.toStringAsFixed(2)} DZD'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<SalesBloc>().add(ResetSale());
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => DocumentViewerPage(saleId: state.response['sale_id']),
              ));
            },
            child: const Text('Print Document'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<SalesBloc>().add(ResetSale());
            },
            child: const Text('New Sale'),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
  double _getPriceForType(Map<String, dynamic> product, String saleType) {
    final pricing = product['product_pricing'];
    if (pricing == null) return 0.0;
    
    if (saleType == 'detail') {
      return (pricing['prix_vente_detail_ht'] as num?)?.toDouble() ?? 0.0;
    } else {
      return (pricing['prix_vente_gros_ht'] as num?)?.toDouble() ?? 0.0;
    }
  }

  double _getStockForType(Map<String, dynamic> product, String saleType) {
    final stock = product['stock'];
    if (stock == null) return 0.0;
    
    if (saleType == 'detail') {
      return (stock['qty_detail'] as num?)?.toDouble() ?? 0.0;
    } else {
      return (stock['qty_gros'] as num?)?.toDouble() ?? 0.0;
    }
  }
}
