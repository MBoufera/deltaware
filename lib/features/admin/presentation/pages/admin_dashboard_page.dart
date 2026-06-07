import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _productsStream;

  @override
  void initState() {
    super.initState();
    _productsStream = _supabase.from('products').stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }

              final products = snapshot.data ?? [];
              
              // Calculate Metrics
              int totalProducts = products.length;
              double totalValue = 0.0;
              List<Map<String, dynamic>> lowStockItems = [];

              for (var p in products) {
                int stock = p['stock'] ?? 0;
                double price = (p['retail_price'] as num?)?.toDouble() ?? 0.0;
                totalValue += (stock * price);
                
                if (stock < 10) {
                  lowStockItems.add(p);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'dashboard.business_overview'.tr(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2A32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'dashboard.live_metrics'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Top Metrics Row
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'dashboard.total_products'.tr(),
                          value: totalProducts.toString(),
                          icon: Icons.inventory_2,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _MetricCard(
                          title: 'dashboard.total_value'.tr(),
                          value: '${totalValue.toStringAsFixed(2)} DZD',
                          icon: Icons.account_balance_wallet,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _MetricCard(
                          title: 'dashboard.low_stock_alerts'.tr(),
                          value: lowStockItems.length.toString(),
                          icon: Icons.warning_amber_rounded,
                          color: lowStockItems.isNotEmpty ? Colors.red : Colors.orange,
                          isAlert: lowStockItems.isNotEmpty,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Low Stock Section
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(
                        'dashboard.items_restock'.tr(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2A32)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
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
                        child: lowStockItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                                    const SizedBox(height: 16),
                                    Text('dashboard.stock_great'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: lowStockItems.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = lowStockItems[index];
                                  final stock = item['stock'] ?? 0;
                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.inventory_2_outlined, color: Colors.red.shade700),
                                    ),
                                    title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Category: ${item['category'] ?? 'N/A'}'),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: stock == 0 ? Colors.red.shade100 : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$stock ${'dashboard.in_stock'.tr()}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: stock == 0 ? Colors.red.shade900 : Colors.orange.shade900,
                                        ),
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
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final MaterialColor color;
  final bool isAlert;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAlert ? Border.all(color: Colors.red.shade200, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color.shade700, size: 28),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('dashboard.action_needed'.tr(), style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.red.shade700 : const Color(0xFF1A2A32),
            ),
          ),
        ],
      ),
    );
  }
}
