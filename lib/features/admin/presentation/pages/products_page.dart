import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final List<Map<String, dynamic>> _dummyProducts = [
    {
      'id': '1',
      'name': 'Laptop XPS 15',
      'category': 'Electronics',
      'stock': 45,
      'purchasePrice': 1200.0,
      'wholesalePrice': 1440.0,
      'retailPrice': 1872.0,
    },
    {
      'id': '2',
      'name': 'Wireless Mouse',
      'category': 'Accessories',
      'stock': 120,
      'purchasePrice': 15.0,
      'wholesalePrice': 20.0,
      'retailPrice': 26.0,
    },
    {
      'id': '3',
      'name': 'Mechanical Keyboard',
      'category': 'Accessories',
      'stock': 85,
      'purchasePrice': 65.0,
      'wholesalePrice': 90.0,
      'retailPrice': 117.0,
    },
  ];

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
                    const Text(
                      'Product Inventory',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2A32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your store products and pricing',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    context.go('/admin-dashboard/products/add');
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add Product',
                    style: TextStyle(
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
                      decoration: const InputDecoration(
                        hintText: 'Search products by name, category, or ID...',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        // Implement search filtering here
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
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                      dataRowMinHeight: 65,
                      dataRowMaxHeight: 65,
                      horizontalMargin: 24,
                      columnSpacing: 32,
                      columns: const [
                        DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Purchase Price', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Wholesale Price', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Retail Price', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _dummyProducts.map((product) {
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
                                    product['name'],
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
                                  product['category'],
                                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${product['stock']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: product['stock'] > 20 ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ),
                            DataCell(Text('\$${product['purchasePrice'].toStringAsFixed(2)}')),
                            DataCell(Text('\$${product['wholesalePrice'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(
                              Text(
                                '\$${product['retailPrice'].toStringAsFixed(2)}',
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
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
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
