import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1).toIso8601String();
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

      final data = await _supabase.rpc('get_analytics', params: {
        'start_date': startDate,
        'end_date': endDate,
      });

      if (mounted) {
        setState(() {
          _analytics = data;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_analytics == null) return const Scaffold(body: Center(child: Text('Failed to load analytics')));

    final kpi = _analytics!['kpi'];
    final timeline = List<dynamic>.from(_analytics!['timeline'] ?? []);
    final topWorkers = List<dynamic>.from(_analytics!['top_workers'] ?? []);
    final topProducts = List<dynamic>.from(_analytics!['top_products'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('dashboard.business_overview'.tr(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A2A32))),
              Text('Performance ce mois', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 32),
              
              // KPIs
              Row(
                children: [
                  Expanded(child: _MetricCard(title: 'Chiffre d\'Affaire HT', value: '${(kpi['total_revenue_ht'] as num).toStringAsFixed(2)} DZD', icon: Icons.attach_money, color: Colors.blue)),
                  const SizedBox(width: 24),
                  Expanded(child: _MetricCard(title: 'Bénéfice Brut', value: '${(kpi['gross_profit'] as num).toStringAsFixed(2)} DZD', icon: Icons.trending_up, color: Colors.green)),
                  const SizedBox(width: 24),
                  Expanded(child: _MetricCard(title: 'Nombre de Ventes', value: kpi['sales_count'].toString(), icon: Icons.receipt_long, color: Colors.orange)),
                  const SizedBox(width: 24),
                  Expanded(child: _MetricCard(title: 'Marge %', value: '${(kpi['margin_percent'] as num).toStringAsFixed(1)}%', icon: Icons.percent, color: Colors.purple)),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Chart & Leaderboards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Chart
                  Expanded(
                    flex: 7,
                    child: Container(
                      height: 400,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Évolution des Revenus & Bénéfices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          Expanded(child: _buildTimelineChart(timeline)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  
                  // Side Panels
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildLeaderboard('Meilleurs Vendeurs', topWorkers, (w) => w['name'], (w) => '${(w['revenue_ht'] as num).toStringAsFixed(0)} DZD'),
                        const SizedBox(height: 24),
                        _buildLeaderboard('Top Produits', topProducts, (p) => p['name_fr'], (p) => '${p['qty_sold']} unités'),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineChart(List<dynamic> timeline) {
    if (timeline.isEmpty) return const Center(child: Text('Aucune donnée pour ce mois'));

    final spotsRevenue = <FlSpot>[];
    final spotsProfit = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < timeline.length; i++) {
      final t = timeline[i];
      final rev = (t['revenue_ht'] as num).toDouble();
      final prof = (t['gross_profit'] as num).toDouble();
      
      if (rev > maxY) maxY = rev;
      
      spotsRevenue.add(FlSpot(i.toDouble(), rev));
      spotsProfit.add(FlSpot(i.toDouble(), prof));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= timeline.length) return const Text('');
              final dateStr = timeline[index]['date_label'] as String;
              final day = dateStr.split('-').last;
              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(day, style: const TextStyle(fontSize: 10)));
            },
          )),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (timeline.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spotsRevenue,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
          ),
          LineChartBarData(
            spots: spotsProfit,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(String title, List<dynamic> items, String Function(dynamic) getTitle, String Function(dynamic) getSubtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          items.isEmpty ? const Text('Aucune donnée') : Column(
            children: items.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: const Color(0xFF1A2A32), child: Text(getTitle(item).substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white))),
              title: Text(getTitle(item), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(getSubtitle(item), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2A32)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
