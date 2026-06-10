import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../bloc/product/product_bloc.dart';
import '../bloc/product/product_event.dart';
import '../bloc/product/product_state.dart';
import '../../../../core/widgets/permission_guard.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: 'can_manage_products',
      child: BlocProvider(
        create: (context) => ProductBloc()..add(const LoadProducts()),
        child: const ProductsView(),
      ),
    );
  }
}

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'products.title'.tr(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2A32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'products.subtitle'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await context.push('/admin-dashboard/products/add');
                    // Reload products list when returning
                    if (context.mounted) {
                      context.read<ProductBloc>().add(LoadProducts(search: _searchController.text));
                    }
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'products.add_product'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: Colors.blue.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'products.search_hint'.tr(),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        context.read<ProductBloc>().add(LoadProducts(search: value));
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    color: Colors.grey.shade600,
                    onPressed: () {},
                  )
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BlocBuilder<ProductBloc, ProductState>(
                    builder: (context, state) {
                      if (state is ProductLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (state is ProductError) {
                        return Center(
                          child: Text('Error loading products: ${state.message}'),
                        );
                      }
                      
                      final products = state is ProductsLoaded ? state.products : <Map<String, dynamic>>[];
                      
                      if (products.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text('products.no_products'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 16)),
                              ],
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                            dataRowMinHeight: 65,
                            dataRowMaxHeight: 65,
                            horizontalMargin: 24,
                            columnSpacing: 32,
                            columns: [
                              DataColumn(label: Text('products.col_name'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('products.col_category'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('products.col_stock'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('products.col_purchase'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('products.col_wholesale'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('products.col_retail'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('products.col_actions'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: products.map((product) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.inventory_2_outlined, color: Colors.blue.shade700, size: 20),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          product['name_fr'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        product['categories']?['name_fr'] ?? 'products.uncategorized'.tr(),
                                        style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Builder(
                                      builder: (context) {
                                        final qty = (product['stock']?['qty_detail'] ?? 0) as num;
                                        final threshold = (product['stock']?['alert_threshold'] ?? 5) as num;
                                        final isLowStock = qty <= threshold;
                                        
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: isLowStock ? BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade200),
                                          ) : null,
                                          child: Text(
                                            '$qty',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isLowStock ? Colors.red.shade700 : Colors.green.shade700,
                                            ),
                                          ),
                                        );
                                      }
                                    ),
                                  ),
                                  DataCell(Text('${(product['product_pricing']?['prix_achat_super_gros'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD')),
                                  DataCell(Text('${(product['product_pricing']?['prix_vente_gros_ht'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD', style: const TextStyle(fontWeight: FontWeight.w500))),
                                  DataCell(
                                    Text(
                                      '${(product['product_pricing']?['prix_vente_detail_ht'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          color: Colors.blue.shade600,
                                          onPressed: () {},
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                          color: Colors.red.shade400,
                                          onPressed: () {
                                            final id = product['id'] as String;
                                            context.read<ProductBloc>().add(DeleteProduct(id));
                                            context.read<ProductBloc>().add(LoadProducts(search: _searchController.text));
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
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
