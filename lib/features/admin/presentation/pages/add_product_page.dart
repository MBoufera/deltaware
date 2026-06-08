import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
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
    // Add listeners to auto-calculate when values change
    _purchasePriceController.addListener(_calculatePrices);
    _wholesaleMarginController.addListener(_calculatePrices);
    _retailMultiplierController.addListener(_calculatePrices);
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
    final double purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
    final double marginPercent = double.tryParse(_wholesaleMarginController.text) ?? 0.0;
    final double retailMultiplier = double.tryParse(_retailMultiplierController.text) ?? 1.30;

    // Wholesale = Purchase Price + (Purchase Price * Margin %)
    final double calculatedWholesale = purchasePrice + (purchasePrice * (marginPercent / 100));
    
    // Retail = Wholesale Price * Retail Multiplier
    final double calculatedRetail = calculatedWholesale * retailMultiplier;

    setState(() {
      _wholesalePrice = calculatedWholesale;
      _retailPrice = calculatedRetail;
    });
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        final supabase = Supabase.instance.client;
        
        final categoryName = _categoryController.text.isEmpty ? 'products.uncategorized'.tr() : _categoryController.text;
        var categoryResponse = await supabase.from('categories').select('id').eq('name_fr', categoryName).maybeSingle();
        String categoryId;
        if (categoryResponse == null) {
          final newCat = await supabase.from('categories').insert({'name_fr': categoryName}).select('id').single();
          categoryId = newCat['id'];
        } else {
          categoryId = categoryResponse['id'];
        }
        
        final productResponse = await supabase.from('products').insert({
          'name_fr': _nameController.text,
          'ref_code': _barcodeController.text.isEmpty ? null : _barcodeController.text,
          'category_id': categoryId,
        }).select('id').single();
        final productId = productResponse['id'];
        
        final retailMultiplier = double.tryParse(_retailMultiplierController.text) ?? 1.30;
        final margeDetail = (retailMultiplier - 1.0) * 100;
        
        await supabase.from('product_pricing').insert({
          'product_id': productId,
          'prix_achat_super_gros': double.tryParse(_purchasePriceController.text) ?? 0.0,
          'marge_gros_percent': double.tryParse(_wholesaleMarginController.text) ?? 0.0,
          'marge_detail_percent': margeDetail,
          'tva_rate': double.tryParse(_tvaController.text) ?? 19.0,
        });
        
        await supabase.from('stock').insert({
          'product_id': productId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('add_product.success'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          context.pop(); // Go back to products list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving product: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    String? suffixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'add_product.error_empty'.tr();
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade300),
        suffixText: suffixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A2A32)),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: 800, // Fixed width for nice layout on desktop
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT SIDE: Input Form
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'add_product.title'.tr(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A2A32),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'add_product.subtitle'.tr(),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 32),
                          
                          // Basic Info
                          Text('add_product.basic_info'.tr().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _nameController, label: 'add_product.product_name'.tr(), icon: Icons.inventory_2_outlined),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _barcodeController, 
                            label: 'add_product.barcode'.tr(), 
                            icon: Icons.qr_code_scanner,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _categoryController, label: 'add_product.category'.tr(), icon: Icons.category_outlined),
                          
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 32),

                          // Pricing & Margins
                          Text('add_product.pricing_margins'.tr().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(controller: _purchasePriceController, label: 'add_product.purchase_price'.tr(), icon: Icons.attach_money, isNumber: true)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField(controller: _tvaController, label: 'add_product.tva'.tr(), icon: Icons.percent, isNumber: true, suffixText: '%')),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(controller: _wholesaleMarginController, label: 'add_product.wholesale_margin'.tr(), icon: Icons.trending_up, isNumber: true, suffixText: '%')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField(controller: _retailMultiplierController, label: 'add_product.retail_multiplier'.tr(), icon: Icons.storefront, isNumber: true, suffixText: 'x')),
                            ],
                          ),
                          const SizedBox(height: 40),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _saveProduct,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A2A32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(
                                'add_product.save'.tr(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // RIGHT SIDE: Live Preview Card
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border(left: BorderSide(color: Colors.grey.shade200)),
                    ),
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'add_product.calculated_prices'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2A32),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        _PriceCard(
                          title: 'add_product.purchase_price'.tr(),
                          subtitle: '',
                          price: double.tryParse(_purchasePriceController.text) ?? 0.0,
                          icon: Icons.shopping_cart_outlined,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 24),
                        
                        _PriceCard(
                          title: 'add_product.wholesale_price'.tr(),
                          subtitle: '',
                          price: _wholesalePrice,
                          icon: Icons.local_shipping_outlined,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(height: 24),
                        
                        _PriceCard(
                          title: 'add_product.retail_price'.tr(),
                          subtitle: '',
                          price: _retailPrice,
                          icon: Icons.storefront,
                          color: Colors.green.shade700,
                          isHighlight: true,
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
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double price;
  final IconData icon;
  final Color color;
  final bool isHighlight;

  const _PriceCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.color,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlight ? Border.all(color: Colors.green.shade200, width: 2) : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          if (isHighlight)
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${price.toStringAsFixed(2)} DZD',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
