import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../../../store/presentation/bloc/store_state.dart';
import '../bloc/product/product_bloc.dart';
import '../bloc/product/product_event.dart';
import '../bloc/product/product_state.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canManageProducts.key,
      child: BlocProvider(
        create: (context) {
          final storeState = context.read<StoreBloc>().state;
          final storeId = storeState is StoresLoaded ? storeState.selectedStore?.id : null;
          return ProductBloc()..add(LoadProducts(storeId: storeId));
        },
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
  bool _showLowStockOnly = false;
  String? _selectedCategory;

  String? _getStoreId() {
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoresLoaded ? storeState.selectedStore?.id : null;
  }

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 14,
    color: Color(0xFF1A2A32),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('products.delete_confirm_title'.tr()),
        content: Text('products.delete_confirm_desc'.tr(args: [product['name_fr'] ?? ''])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final id = product['id'] as String;
              context.read<ProductBloc>().add(DeleteProduct(id));
              context.read<ProductBloc>().add(LoadProducts(search: _searchController.text, storeId: _getStoreId()));
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('products.col_name'.tr(), style: _headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('products.col_category'.tr(), style: _headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('products.col_stock'.tr(), style: _headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('products.col_purchase'.tr(), style: _headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('products.col_wholesale'.tr(), style: _headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('products.col_retail'.tr(), style: _headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('products.col_actions'.tr(), style: _headerStyle),
          ),
        ],
      ),
    );
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
            // Header Row
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
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'products.subtitle'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                _AddProductButton(
                  onTap: () async {
                    await context.push('/dashboard/products/add');
                    if (context.mounted) {
                      context.read<ProductBloc>().add(
                        LoadProducts(search: _searchController.text, storeId: _getStoreId()),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Stats & Main Table Bloc Builder
            Expanded(
              child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
                  final isLoading = state is ProductLoading;
                  final allProducts = state is ProductsLoaded
                      ? state.products
                      : <Map<String, dynamic>>[];

                  // Compute Stats dynamically
                  final totalProducts = allProducts.length;
                  final lowStockCount = allProducts.where((p) {
                    final qty = (p['stock']?['qty_detail'] ?? 0) as num;
                    final threshold = (p['stock']?['alert_threshold'] ?? 5) as num;
                    return qty <= threshold;
                  }).length;
                  final totalValue = allProducts.fold<double>(0.0, (sum, p) {
                    final qty = (p['stock']?['qty_detail'] ?? 0) as num;
                    final price = (p['product_pricing']?['prix_achat_super_gros'] ?? 0) as num;
                    return sum + (qty * price);
                  });

                  // Extract Categories for Filtering
                  final categories = allProducts
                      .map((p) => p['categories']?['name_fr'] as String?)
                      .where((name) => name != null)
                      .cast<String>()
                      .toSet()
                      .toList();
                  categories.sort();

                  // Apply search and filters local logic
                  var filteredProducts = allProducts;
                  if (_showLowStockOnly) {
                    filteredProducts = filteredProducts.where((product) {
                      final qty = (product['stock']?['qty_detail'] ?? 0) as num;
                      final threshold = (product['stock']?['alert_threshold'] ?? 5) as num;
                      return qty <= threshold;
                    }).toList();
                  }
                  if (_selectedCategory != null) {
                    filteredProducts = filteredProducts.where((product) {
                      final catName = product['categories']?['name_fr'] as String?;
                      return catName == _selectedCategory;
                    }).toList();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Stat Cards Dashboard
                      if (!isLoading && state is! ProductError && allProducts.isNotEmpty) ...[
                        Row(
                          children: [
                            _StatCard(
                              title: 'Total Products',
                              value: '$totalProducts',
                              icon: Icons.inventory_2_outlined,
                              iconColor: const Color(0xFF203A43),
                              iconBgColor: const Color(0xFF203A43).withValues(alpha: 0.08),
                            ),
                            const SizedBox(width: 20),
                            _StatCard(
                              title: 'Low Stock Alerts',
                              value: '$lowStockCount',
                              icon: Icons.warning_amber_rounded,
                              iconColor: const Color(0xFFDC2626),
                              iconBgColor: const Color(0xFFDC2626).withValues(alpha: 0.08),
                            ),
                            const SizedBox(width: 20),
                            _StatCard(
                              title: 'Stock Valuation (Achat)',
                              value: '${totalValue.toStringAsFixed(2)} DZD',
                              icon: Icons.payments_outlined,
                              iconColor: const Color(0xFF10B981),
                              iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.08),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Search and Filter Bar
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
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'products.search_hint'.tr(),
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                onChanged: (value) {
                                  context.read<ProductBloc>().add(
                                    LoadProducts(search: value, storeId: _getStoreId()),
                                  );
                                },
                              ),
                            ),
                            if (categories.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _selectedCategory,
                                    dropdownColor: Colors.white,
                                    hint: Text(
                                      'products.all_categories'.tr(),
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          'products.all_categories'.tr(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      ...categories.map((cat) => DropdownMenuItem<String?>(
                                            value: cat,
                                            child: Text(
                                              cat,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedCategory = val;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _showLowStockOnly = !_showLowStockOnly;
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _showLowStockOnly
                                        ? Colors.red.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _showLowStockOnly
                                          ? Colors.red.shade200
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: _showLowStockOnly
                                            ? Colors.red.shade700
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'products.low_stock'.tr(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _showLowStockOnly
                                              ? Colors.red.shade700
                                              : Colors.grey.shade700,
                                          fontWeight: _showLowStockOnly
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Custom Data Table/Grid Container
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF203A43),
                                    ),
                                  )
                                : state is ProductError
                                ? Center(
                                    child: Text(
                                      'Error loading products: ${state.message}',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                : filteredProducts.isEmpty
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
                                              Icons.inventory_2_outlined,
                                              size: 64,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'products.no_products'.tr(),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final tableWidth = constraints.maxWidth > 900
                                          ? constraints.maxWidth
                                          : 900.0;
                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: tableWidth,
                                          child: Column(
                                            children: [
                                              _buildTableHeader(),
                                              Expanded(
                                                child: ListView.builder(
                                                  itemCount: filteredProducts.length,
                                                  itemBuilder: (context, index) {
                                                    final product = filteredProducts[index];
                                                    return _ProductRow(
                                                      product: product,
                                                      onEdit: () async {
                                                        await context.push(
                                                          '/dashboard/products/add',
                                                          extra: product,
                                                        );
                                                        if (context.mounted) {
                                                          context.read<ProductBloc>().add(
                                                                LoadProducts(
                                                                  search: _searchController.text,
                                                                  storeId: _getStoreId(),
                                                                ),
                                                              );
                                                        }
                                                      },
                                                      onDelete: () {
                                                        _showDeleteDialog(context, product);
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
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

// ─── Custom Product Row Widget ───────────────────────────────────────────────

class _ProductRow extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRow({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final qty = (widget.product['stock']?['qty_detail'] ?? 0) as num;
    final threshold = (widget.product['stock']?['alert_threshold'] ?? 5) as num;
    final isLowStock = qty <= threshold;
    final isOutOfStock = qty == 0;
    final double progress = (qty / (threshold * 3.0)).clamp(0.0, 1.0);

    // Dynamic stock badge
    Widget stockBadge;
    if (isOutOfStock) {
      stockBadge = _buildBadge(
        text: 'Out of Stock',
        textColor: Colors.red.shade700,
        bgColor: Colors.red.shade50,
      );
    } else if (isLowStock) {
      stockBadge = _buildBadge(
        text: 'Low Stock',
        textColor: Colors.orange.shade700,
        bgColor: Colors.orange.shade50,
      );
    } else {
      stockBadge = _buildBadge(
        text: 'In Stock',
        textColor: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            // Product Name
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isLowStock
                          ? Colors.red.shade50
                          : const Color(0xFF203A43).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: isLowStock ? Colors.red.shade700 : const Color(0xFF203A43),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.product['name_fr'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            if (widget.product['ref_code'] != null &&
                                widget.product['ref_code'].toString().isNotEmpty) ...[
                              Text(
                                widget.product['ref_code'].toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Text(
                              'Contenance: ${widget.product['contenance'] ?? 1} pcs/bte',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Category
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.product['categories']?['name_fr'] ?? 'products.uncategorized'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            // Stock Level
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        '$qty units',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isLowStock ? Colors.red.shade700 : const Color(0xFF1E293B),
                        ),
                      ),
                      stockBadge,
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 100,
                      height: 5,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLowStock ? Colors.red.shade500 : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Pricing Columns
            Expanded(
              flex: 2,
              child: Text(
                '${(widget.product['product_pricing']?['prix_achat_super_gros'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${(widget.product['product_pricing']?['prix_vente_gros_ht'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${(widget.product['product_pricing']?['prix_vente_detail_ht'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203A43),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            // Actions
            Expanded(
              flex: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: Colors.blue.shade600,
                    onPressed: widget.onEdit,
                    tooltip: 'Edit Product',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red.shade400,
                    onPressed: widget.onDelete,
                    tooltip: 'Delete Product',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Stat Card Widget ────────────────────────────────────────────────────────

class _StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.03),
                  blurRadius: _isHovered ? 16 : 10,
                  offset: Offset(0, _isHovered ? 8 : 5),
                ),
              ],
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFF203A43).withValues(alpha: 0.2)
                    : Colors.grey.shade100,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2A32),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

// ─── Add Product Button Widget ──────────────────────────────────────────────

class _AddProductButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AddProductButton({required this.onTap});

  @override
  State<_AddProductButton> createState() => _AddProductButtonState();
}

class _AddProductButtonState extends State<_AddProductButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF203A43).withValues(alpha: _isHovered ? 0.35 : 0.2),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: widget.onTap,
            icon: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              'products.add_product'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

