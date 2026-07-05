import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../store/presentation/bloc/store_state.dart';
import '../bloc/product/product_bloc.dart';
import '../bloc/product/product_event.dart';
import '../bloc/product/product_state.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';

class AddProductPage extends StatelessWidget {
  final Map<String, dynamic>? product;
  const AddProductPage({super.key, this.product});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductBloc(),
      child: AddProductForm(product: product),
    );
  }
}

class AddProductForm extends StatefulWidget {
  final Map<String, dynamic>? product;
  const AddProductForm({super.key, this.product});

  @override
  State<AddProductForm> createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _wholesaleMarginController = TextEditingController();
  final _retailMultiplierController = TextEditingController(text: '1.30');
  final _tvaController = TextEditingController(text: '19'); // Default 19% TVA

  // Calculated values
  double _wholesalePrice = 0.0;
  double _retailPrice = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p['name_fr'] ?? '';
      _barcodeController.text = p['ref_code'] ?? '';
      _categoryController.text = p['categories']?['name_fr'] ?? '';

      final pricing = p['product_pricing'];
      if (pricing != null) {
        _purchasePriceController.text =
            (pricing['prix_achat_super_gros'] as num?)?.toString() ?? '0';
        _wholesaleMarginController.text =
            (pricing['marge_gros_percent'] as num?)?.toString() ?? '0';
        _tvaController.text = (pricing['tva_rate'] as num?)?.toString() ?? '19';

        // Convert marge detail back to retail multiplier
        final margeDetail =
            (pricing['marge_detail_percent'] as num?)?.toDouble() ?? 30.0;
        final retailMultiplier = 1.0 + (margeDetail / 100);
        _retailMultiplierController.text = retailMultiplier.toStringAsFixed(2);
      }
    }

    // Add listeners to auto-calculate when values change
    _purchasePriceController.addListener(_calculatePrices);
    _wholesaleMarginController.addListener(_calculatePrices);
    _retailMultiplierController.addListener(_calculatePrices);

    if (widget.product != null) {
      _calculatePrices();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _wholesaleMarginController.dispose();
    _retailMultiplierController.dispose();
    _tvaController.dispose();
    super.dispose();
  }

  void _calculatePrices() {
    final double purchasePrice =
        double.tryParse(_purchasePriceController.text) ?? 0.0;
    final double marginPercent =
        double.tryParse(_wholesaleMarginController.text) ?? 0.0;
    final double retailMultiplier =
        double.tryParse(_retailMultiplierController.text) ?? 1.30;

    // Wholesale = Purchase Price + (Purchase Price * Margin %)
    final double calculatedWholesale =
        purchasePrice + (purchasePrice * (marginPercent / 100));

    // Retail = Wholesale Price * Retail Multiplier
    final double calculatedRetail = calculatedWholesale * retailMultiplier;

    setState(() {
      _wholesalePrice = calculatedWholesale;
      _retailPrice = calculatedRetail;
    });
  }

  void _saveProduct() {
    if (_formKey.currentState!.validate()) {
      final purchasePrice =
          double.tryParse(_purchasePriceController.text) ?? 0.0;
      final tva = double.tryParse(_tvaController.text) ?? 19.0;
      final marginPercent =
          double.tryParse(_wholesaleMarginController.text) ?? 0.0;
      final retailMultiplier =
          double.tryParse(_retailMultiplierController.text) ?? 1.30;
      final categoryName = _categoryController.text.isEmpty
          ? 'products.uncategorized'.tr()
          : _categoryController.text;

      final storeState = context.read<StoreBloc>().state;
      final storeId = storeState is StoresLoaded ? storeState.selectedStore?.id : null;

      if (widget.product != null) {
        context.read<ProductBloc>().add(
          UpdateProduct(
            id: widget.product!['id'],
            nameFr: _nameController.text,
            refCode: _barcodeController.text.isEmpty
                ? null
                : _barcodeController.text,
            categoryName: categoryName,
            purchasePrice: purchasePrice,
            tva: tva,
            wholesaleMargin: marginPercent,
            retailMultiplier: retailMultiplier,
            storeId: storeId,
          ),
        );
      } else {
        context.read<ProductBloc>().add(
          CreateProduct(
            nameFr: _nameController.text,
            refCode: _barcodeController.text.isEmpty
                ? null
                : _barcodeController.text,
            categoryName: categoryName,
            purchasePrice: purchasePrice,
            tva: tva,
            wholesaleMargin: marginPercent,
            retailMultiplier: retailMultiplier,
            storeId: storeId,
          ),
        );
      }
    }
  }

  Widget _buildSectionHeader(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF203A43),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'add_product.error_empty'.tr();
            }
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
            suffixText: suffixText,
            suffixStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF203A43),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listener: (context, state) {
        if (state is ProductOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('add_product.success'.tr()),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          context.pop(true); // Go back to products list indicating success
        } else if (state is ProductError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving product: ${state.message}'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Title Area
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                child: Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF1E293B),
                            size: 18,
                          ),
                          onPressed: () => context.pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product != null
                              ? 'Edit Product'
                              : 'add_product.title'.tr(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product != null
                              ? 'Update the details for this product'
                              : 'add_product.subtitle'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isWide = constraints.maxWidth > 950;

                      final formWidget = Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic Info
                            _buildSectionHeader(
                              'add_product.basic_info'.tr().toUpperCase(),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _nameController,
                                    label: 'add_product.product_name'.tr(),
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildTextField(
                                    controller: _barcodeController,
                                    label: 'add_product.barcode'.tr(),
                                    icon: Icons.qr_code_scanner,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _categoryController,
                              label: 'add_product.category'.tr(),
                              icon: Icons.category_outlined,
                            ),

                            const SizedBox(height: 32),
                            const Divider(height: 1),
                            const SizedBox(height: 32),

                            // Pricing & Margins
                            _buildSectionHeader(
                              'add_product.pricing_margins'.tr().toUpperCase(),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _purchasePriceController,
                                    label: 'add_product.purchase_price'.tr(),
                                    icon: Icons.attach_money,
                                    isNumber: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildTextField(
                                    controller: _tvaController,
                                    label: 'add_product.tva'.tr(),
                                    icon: Icons.percent,
                                    isNumber: true,
                                    suffixText: '%',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _wholesaleMarginController,
                                    label: 'add_product.wholesale_margin'.tr(),
                                    icon: Icons.trending_up,
                                    isNumber: true,
                                    suffixText: '%',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _retailMultiplierController,
                                    label: 'add_product.retail_multiplier'.tr(),
                                    icon: Icons.storefront,
                                    isNumber: true,
                                    suffixText: 'x',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      final previewWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'add_product.calculated_prices'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _PriceCard(
                            title: 'add_product.purchase_price'.tr(),
                            price:
                                double.tryParse(
                                  _purchasePriceController.text,
                                ) ??
                                0.0,
                            icon: Icons.shopping_cart_outlined,
                            color: const Color(0xFFD97706),
                            iconBgColor: const Color(0xFFFEF3C7),
                          ),
                          const SizedBox(height: 20),

                          _PriceCard(
                            title: 'add_product.wholesale_price'.tr(),
                            price: _wholesalePrice,
                            icon: Icons.local_shipping_outlined,
                            color: const Color(0xFF4F46E5),
                            iconBgColor: const Color(0xFFEEF2FF),
                          ),
                          const SizedBox(height: 20),

                          _PriceCard(
                            title: 'add_product.retail_price'.tr(),
                            price: _retailPrice,
                            icon: Icons.storefront_rounded,
                            color: const Color(0xFF059669),
                            iconBgColor: const Color(0xFFECFDF5),
                            isHighlight: true,
                          ),
                          const SizedBox(height: 32),

                          BlocBuilder<ProductBloc, ProductState>(
                            builder: (context, state) {
                              final isLoading = state is ProductLoading;
                              return _SubmitButton(
                                isLoading: isLoading,
                                onPressed: isLoading ? null : _saveProduct,
                                label: 'add_product.save'.tr(),
                              );
                            },
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: formWidget,
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: previewWidget,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: formWidget,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: previewWidget,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;

  const _SubmitButton({
    required this.isLoading,
    required this.onPressed,
    required this.label,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = enabled),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF203A43) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(
                        0xFF203A43,
                      ).withValues(alpha: _isHovered ? 0.35 : 0.2),
                      blurRadius: _isHovered ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String title;
  final double price;
  final IconData icon;
  final Color color;
  final Color iconBgColor;
  final bool isHighlight;

  const _PriceCard({
    required this.title,
    required this.price,
    required this.icon,
    required this.color,
    required this.iconBgColor,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlight
              ? color.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: isHighlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighlight ? 0.03 : 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'DZD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
