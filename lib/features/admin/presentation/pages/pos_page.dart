import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/sales/sales_bloc.dart';
import '../bloc/sales/sales_event.dart';
import '../bloc/sales/sales_state.dart';
import '../widgets/client_selection_dialog.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../../features/store/presentation/bloc/store_event.dart';
import '../../../../features/store/presentation/bloc/store_state.dart';
import 'document_viewer_page.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductsForCurrentStore();
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadProductsForCurrentStore() {
    final storeState = context.read<StoreBloc>().state;
    String? storeId;
    if (storeState is StoresLoaded) storeId = storeState.selectedStore?.id;

    if (storeId != null) {
      context.read<SalesBloc>().add(LoadProducts(storeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<StoreBloc, StoreState>(
          listenWhen: (prev, curr) {
            final prevId = prev is StoresLoaded ? prev.selectedStore?.id : null;
            final currId = curr is StoresLoaded ? curr.selectedStore?.id : null;
            return prevId != currId;
          },
          listener: (context, state) {
            if (state is StoresLoaded && state.selectedStore != null) {
              context.read<SalesBloc>().add(LoadProducts(state.selectedStore!.id));
            }
          },
        ),
        BlocListener<SalesBloc, SalesState>(
          listener: (context, state) {
            if (state is SalesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
              );
            } else if (state is SalesSuccess) {
              _showSuccessDialog(context, state);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: BlocBuilder<StoreBloc, StoreState>(
          builder: (context, storeState) {
            if (storeState is StoreInitial || storeState is StoreLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF203A43),
                ),
              );
            }

            if (storeState is StoreError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load store context',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        storeState.message,
                        style: const TextStyle(color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.read<StoreBloc>().add(LoadUserStores()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2A32),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (storeState is StoresLoaded) {
              if (storeState.selectedStore == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Store Context Selected',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please select a store first to manage point of sale.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/store-select'),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Select Store'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2A32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Store is selected, now load products BLoC
              return BlocBuilder<SalesBloc, SalesState>(
                builder: (context, salesState) {
                  if (salesState is SalesInitial || salesState is SalesLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF203A43),
                      ),
                    );
                  } else if (salesState is SalesUpdated) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              _buildTopBar(salesState),
                              Expanded(child: _buildProductGrid(salesState)),
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
                              border: Border(
                                left: BorderSide(color: Colors.grey.shade200, width: 1),
                              ),
                            ),
                            child: _buildCart(salesState),
                          ),
                        ),
                      ],
                    );
                  } else if (salesState is SalesError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to Load Products',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              salesState.message,
                              style: const TextStyle(color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.read<SalesBloc>().add(LoadProducts(storeState.selectedStore!.id)),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A2A32),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const Center(child: Text('Unexpected State'));
                },
              );
            }

            return const Center(child: Text('Unexpected Store State'));
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(SalesUpdated state) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sale Type Pill Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildSaleTypeSelector(state),
          ),
          const SizedBox(height: 20),
          // Search Field
          TextField(
            focusNode: _searchFocusNode,
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search products by name or reference...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF203A43), width: 2),
              ),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            onChanged: (query) => context.read<SalesBloc>().add(SearchProducts(query)),
            onSubmitted: (value) {
              final query = value.trim();
              if (query.isNotEmpty) {
                final matchedProduct = state.products.firstWhere(
                  (p) {
                    final refCode = p['ref_code']?.toString().toLowerCase().trim();
                    final reference = p['reference']?.toString().toLowerCase().trim();
                    return refCode == query.toLowerCase() || reference == query.toLowerCase();
                  },
                  orElse: () => null,
                );
                if (matchedProduct != null) {
                  _searchController.clear();
                  context.read<SalesBloc>().add(const SearchProducts(''));
                  if (state.saleType == 'gros') {
                    _showQuantityDialog(context, matchedProduct, state.saleType);
                  } else {
                    context.read<SalesBloc>().add(AddItemToCart(matchedProduct));
                    _searchFocusNode.requestFocus();
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaleTypeSelector(SalesUpdated state) {
    final types = [
      {'key': 'detail', 'label': 'Détail', 'icon': Icons.shopping_bag_outlined},
      {'key': 'gros', 'label': 'Gros', 'icon': Icons.storefront_rounded},
      {'key': 'bon_livraison', 'label': 'BL', 'icon': Icons.local_shipping_outlined},
      {'key': 'bon_commande', 'label': 'BC', 'icon': Icons.description_outlined},
      {'key': 'gouvernement', 'label': 'Gouvernement', 'icon': Icons.account_balance_outlined},
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: types.map((t) {
          final isSelected = state.saleType == t['key'];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                context.read<SalesBloc>().add(SelectSaleType(t['key'] as String));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF203A43) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF203A43).withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductGrid(SalesUpdated state) {
    if (state.filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No products match your search',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: state.filteredProducts.length,
      itemBuilder: (context, index) {
        final p = state.filteredProducts[index];
        final price = _getPriceForType(p, state.saleType);
        final stock = _getStockForType(p, state.saleType);

        return _ProductPosCard(
          product: p,
          price: price,
          stock: stock,
          saleType: state.saleType,
          onTap: () {
            if (state.saleType == 'gros') {
              _showQuantityDialog(context, p, state.saleType);
            } else {
              context.read<SalesBloc>().add(AddItemToCart(p));
            }
          },
        );
      },
    );
  }

  Widget _buildCart(SalesUpdated state) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Sale',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (state.cart.isNotEmpty)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton.icon(
                    onPressed: () => context.read<SalesBloc>().add(ResetSale(state.storeId)),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFB91C1C)),
                    label: const Text(
                      'Clear',
                      style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: state.cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Cart is empty',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: state.cart.length,
                  itemBuilder: (context, index) {
                    final id = state.cart.keys.elementAt(index);
                    final qty = state.cart[id]!;
                    final p = state.products.firstWhere((p) => p['id'] == id);
                    final price = _getPriceForType(p, state.saleType);
                    final total = price * qty;
                    final contenance = p['contenance'] as int? ?? 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF203A43).withValues(alpha: 0.08),
                            child: Text(
                              p['name_fr'].toString().isNotEmpty ? p['name_fr'].toString()[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Color(0xFF203A43),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name_fr'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  state.saleType == 'gros' && contenance > 1
                                      ? '${price.toStringAsFixed(2)} DZD/pc • 1 bte = $contenance pcs'
                                      : '${price.toStringAsFixed(2)} DZD',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (state.saleType == 'gros' && contenance > 1) ...[
                            // Box controller
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Boîte',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_rounded, size: 12),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                        color: const Color(0xFF475569),
                                        onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, -contenance)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          '${qty ~/ contenance}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_rounded, size: 12),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                        color: const Color(0xFF475569),
                                        onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, contenance)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // Piece controller
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Pièce',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_rounded, size: 12),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                        color: const Color(0xFF475569),
                                        onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, -1)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          '${qty % contenance}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_rounded, size: 12),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                        color: const Color(0xFF475569),
                                        onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, 1)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                children: [
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_rounded, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      color: const Color(0xFF475569),
                                      onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, -1)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.add_rounded, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      color: const Color(0xFF475569),
                                      onPressed: () => context.read<SalesBloc>().add(UpdateItemQty(id, 1)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${total.toStringAsFixed(2)} DZD',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                  color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
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
        color: const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          _buildClientSelector(state),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text(
              'Timbre Fiscal (1%)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            value: state.timbreFiscalEnabled,
            onChanged: (v) => context.read<SalesBloc>().add(ToggleTimbreFiscal(v)),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: const Color(0xFF203A43),
          ),
          const Divider(height: 24),
          _buildSummaryRow('Total HT', state.totalHt),
          ...state.tvaBreakdown.entries.map((e) => _buildSummaryRow('TVA ${e.key}%', e.value)),
          if (state.timbreFiscalEnabled) _buildSummaryRow('Timbre', state.timbreFiscal),
          const Divider(height: 24, thickness: 1.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL TTC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              Text(
                '${state.grandTotalTtc.toStringAsFixed(2)} DZD',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (state.cart.isEmpty || state is SalesSubmitting)
                  ? null
                  : () {
                      if (['gros', 'bon_livraison', 'bon_commande', 'gouvernement'].contains(state.saleType) && state.selectedClient == null) {
                        _showClientDialog(state.saleType);
                      } else if (state.saleType == 'gros' && state.selectedClient != null) {
                        _showPaymentDialog(state);
                      } else {
                        context.read<SalesBloc>().add(SubmitSale());
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: state is SalesSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'CONFIRM SALE',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _showPaymentDialog(SalesUpdated state) async {
    double currentDebt = 0.0;
    try {
      final res = await Supabase.instance.client
          .from('client_debts_view')
          .select('total_debt')
          .eq('id', state.selectedClient!['id'])
          .maybeSingle();
      if (res != null) {
        currentDebt = double.tryParse(res['total_debt'].toString()) ?? 0.0;
      }
    } catch (e) {
      // ignore
    }

    if (!mounted) return;

    double defaultPayment = state.grandTotalTtc;
    if (currentDebt < 0) {
      defaultPayment = state.grandTotalTtc + currentDebt;
      if (defaultPayment < 0) defaultPayment = 0;
    }

    final amountController = TextEditingController(text: defaultPayment.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Wholesale Payment', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total amount: ${state.grandTotalTtc.toStringAsFixed(2)} DZD', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (currentDebt < 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Client has a credit of ${(-currentDebt).toStringAsFixed(2)} DZD. Amount to pay has been adjusted automatically.',
                          style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Amount Paid by Client:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: 'DZD',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF203A43), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Remaining debt will be added to ${state.selectedClient!['name']}\'s Fiche Tier.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? state.grandTotalTtc;
                Navigator.of(ctx).pop();
                context.read<SalesBloc>().add(SubmitSale(amountPaid: amount));
              },
              child: const Text('Confirm Sale', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClientSelector(SalesUpdated state) {
    final hasClient = state.selectedClient != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showClientDialog(state.saleType),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasClient ? const Color(0xFF203A43).withValues(alpha: 0.3) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: hasClient ? const Color(0xFF203A43) : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasClient ? state.selectedClient!['name'] : 'Select Client',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hasClient ? const Color(0xFF1E293B) : Colors.grey.shade500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(
            '${amount.toStringAsFixed(2)} DZD',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
          ),
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF10B981),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sale Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sale Reference: ${state.response['sale_number']}\nTotal: ${state.totalTtc.toStringAsFixed(2)} DZD',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 16),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      final storeState = context.read<StoreBloc>().state;
                      final storeId = storeState is StoresLoaded ? storeState.selectedStore?.id : null;
                      if (storeId != null) {
                        context.read<SalesBloc>().add(ResetSale(storeId));
                      }
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => DocumentViewerPage(saleId: state.response['sale_id']),
                      ));
                      _searchFocusNode.requestFocus();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF203A43),
                      side: const BorderSide(color: Color(0xFF203A43)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    label: const Text(
                      'Print',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF203A43),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      final storeState = context.read<StoreBloc>().state;
                      final storeId = storeState is StoresLoaded ? storeState.selectedStore?.id : null;
                      if (storeId != null) {
                        context.read<SalesBloc>().add(ResetSale(storeId));
                      }
                      _searchFocusNode.requestFocus();
                    },
                    child: const Text(
                      'New Sale',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(BuildContext context, Map<String, dynamic> product, String saleType) {
    final contenance = product['contenance'] as int? ?? 1;
    final qtyController = TextEditingController(text: '1');
    final focusNode = FocusNode();
    bool isBox = contenance > 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF203A43).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_basket_outlined,
                      color: Color(0xFF203A43),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name_fr'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (contenance > 1)
                          Text(
                            'Box Capacity: $contenance pcs/bte',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter Quantity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: qtyController,
                    focusNode: focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF203A43), width: 2),
                      ),
                    ),
                    onFieldSubmitted: (val) {
                      final inputQty = int.tryParse(val) ?? 1;
                      final totalPieces = isBox ? inputQty * contenance : inputQty;
                      if (totalPieces > 0) {
                        context.read<SalesBloc>().add(UpdateItemQty(product['id'], totalPieces));
                      }
                      Navigator.of(ctx).pop();
                      _searchFocusNode.requestFocus();
                    },
                  ),
                  if (contenance > 1) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Unit Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: const Text('Box (Boîte)'),
                            ),
                            selected: isBox,
                            selectedColor: const Color(0xFF203A43),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isBox ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                isBox = true;
                              });
                              focusNode.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: const Text('Piece (Pièce)'),
                            ),
                            selected: !isBox,
                            selectedColor: const Color(0xFF203A43),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: !isBox ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                isBox = false;
                              });
                              focusNode.requestFocus();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _searchFocusNode.requestFocus();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF203A43),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final inputQty = int.tryParse(qtyController.text) ?? 1;
                    final totalPieces = isBox ? inputQty * contenance : inputQty;
                    if (totalPieces > 0) {
                      context.read<SalesBloc>().add(UpdateItemQty(product['id'], totalPieces));
                    }
                    Navigator.of(ctx).pop();
                    _searchFocusNode.requestFocus();
                  },
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _getPriceForType(Map<String, dynamic> product, String saleType) {
    final pricing = product['product_pricing'];
    if (pricing == null) return 0.0;

    double basePrice = 0.0;
    if (saleType == 'detail') {
      basePrice = (pricing['prix_vente_detail_ht'] as num?)?.toDouble() ?? 0.0;
    } else {
      basePrice = (pricing['prix_vente_gros_ht'] as num?)?.toDouble() ?? 0.0;
    }
    return (basePrice / 5).roundToDouble() * 5;
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

class _ProductPosCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final double price;
  final double stock;
  final String saleType;
  final VoidCallback onTap;

  const _ProductPosCard({
    required this.product,
    required this.price,
    required this.stock,
    required this.saleType,
    required this.onTap,
  });

  @override
  State<_ProductPosCard> createState() => _ProductPosCardState();
}

class _ProductPosCardState extends State<_ProductPosCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = widget.stock <= 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = !isOutOfStock),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isOutOfStock ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isOutOfStock
              ? Colors.grey.shade50
              : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF203A43).withValues(alpha: 0.15)
                : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: InkWell(
          onTap: isOutOfStock ? null : widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Product Icon Container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.grey.shade100
                        : const Color(0xFF203A43).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: isOutOfStock ? Colors.grey : const Color(0xFF203A43),
                  ),
                ),
                const SizedBox(width: 14),
                // Product Name and Ref Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.product['name_fr'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((widget.product['ref_code'] != null &&
                              widget.product['ref_code'].toString().isNotEmpty) ||
                          (widget.product['reference'] != null &&
                              widget.product['reference'].toString().isNotEmpty) ||
                          (widget.product['contenance'] != null &&
                              (widget.product['contenance'] as num) > 1)) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (widget.product['reference'] != null &&
                                widget.product['reference'].toString().isNotEmpty)
                              'Ref: ${widget.product['reference']}',
                            if (widget.product['ref_code'] != null &&
                                widget.product['ref_code'].toString().isNotEmpty)
                              'Code: ${widget.product['ref_code']}',
                            if (widget.product['contenance'] != null &&
                                (widget.product['contenance'] as num) > 1)
                              '${widget.product['contenance']} pcs/bte',
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Stock Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOutOfStock
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    isOutOfStock ? 'Rupture' : 'En stock: ${widget.stock.toInt()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Price text (pc & bte if in gros mode)
                if (widget.saleType == 'gros' &&
                    widget.product['contenance'] != null &&
                    (widget.product['contenance'] as num) > 1)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.price.toStringAsFixed(2)} DZD/pc',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203A43),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(widget.price * (widget.product['contenance'] as num)).toStringAsFixed(2)} DZD/bte',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.indigo.shade700,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${widget.price.toStringAsFixed(2)} DZD',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF203A43),
                      fontSize: 14,
                      fontFamily: 'monospace',
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
