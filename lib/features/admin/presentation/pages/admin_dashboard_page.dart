import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/colors.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../../features/store/presentation/bloc/store_state.dart';

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
      final endDate = DateTime(
        now.year,
        now.month + 1,
        0,
        23,
        59,
        59,
      ).toIso8601String();

      // Get active store_id for data isolation
      final storeId = context.read<StoreBloc>().currentStoreId;

      final params = <String, dynamic>{
        'start_date': startDate,
        'end_date': endDate,
      };
      if (storeId != null) params['p_store_id'] = storeId;

      final data = await _supabase.rpc('get_analytics', params: params);

      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_analytics == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Failed to load analytics', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    final kpi = _analytics!['kpi'];
    final timeline = List<dynamic>.from(_analytics!['timeline'] ?? []);
    final topWorkers = List<dynamic>.from(_analytics!['top_workers'] ?? []);
    final topProducts = List<dynamic>.from(_analytics!['top_products'] ?? []);

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1100;
    final bool isTablet = screenWidth >= 650 && screenWidth < 1100;
    final bool isMobile = screenWidth < 650;

    // Define the metric cards widgets
    final card1 = _MetricCard(
      title: 'Chiffre d\'Affaire HT',
      value: '${(kpi['total_revenue_ht'] as num).toStringAsFixed(2)} DZD',
      icon: Icons.payments_outlined,
      color: AppColors.primary,
      iconBg: AppColors.primary.withValues(alpha: 0.08),
    );
    final card2 = _MetricCard(
      title: 'Bénéfice Brut',
      value: '${(kpi['gross_profit'] as num).toStringAsFixed(2)} DZD',
      icon: Icons.trending_up_rounded,
      color: AppColors.success,
      iconBg: AppColors.success.withValues(alpha: 0.08),
    );
    final card3 = _MetricCard(
      title: 'Nombre de Ventes',
      value: kpi['sales_count'].toString(),
      icon: Icons.receipt_long_rounded,
      color: AppColors.secondary,
      iconBg: AppColors.secondary.withValues(alpha: 0.08),
    );
    final card4 = _MetricCard(
      title: 'Marge %',
      value: '${(kpi['margin_percent'] as num).toStringAsFixed(1)}%',
      icon: Icons.percent_rounded,
      color: AppColors.warning,
      iconBg: AppColors.warning.withValues(alpha: 0.08),
    );

    // Build the metric cards section responsively
    Widget metricsSection;
    if (isDesktop) {
      metricsSection = Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 20),
          Expanded(child: card2),
          const SizedBox(width: 20),
          Expanded(child: card3),
          const SizedBox(width: 20),
          Expanded(child: card4),
        ],
      );
    } else if (isTablet) {
      metricsSection = Column(
        children: [
          Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 20),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: card3),
              const SizedBox(width: 20),
              Expanded(child: card4),
            ],
          ),
        ],
      );
    } else {
      metricsSection = Column(
        children: [
          card1,
          const SizedBox(height: 16),
          card2,
          const SizedBox(height: 16),
          card3,
          const SizedBox(height: 16),
          card4,
        ],
      );
    }

    final leaderboardWorkers = _buildLeaderboard(
      'Meilleurs Vendeurs',
      topWorkers,
      (w) => w['name'],
      (w) => '${(w['revenue_ht'] as num).toStringAsFixed(0)} DZD',
      Icons.person_rounded,
    );

    final leaderboardProducts = _buildLeaderboard(
      'Top Produits',
      topProducts,
      (p) => p['name_fr'],
      (p) => '${p['qty_sold']} unités',
      Icons.inventory_2_rounded,
    );

    final chartWidget = Container(
      height: 440,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Évolution des Revenus & Bénéfices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  _buildLegendIndicator('Revenus', AppColors.primary),
                  const SizedBox(width: 16),
                  _buildLegendIndicator('Bénéfices', AppColors.success),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(child: _buildTimelineChart(timeline)),
        ],
      ),
    );

    Widget chartsAndLeaderboardsSection;
    if (isDesktop) {
      chartsAndLeaderboardsSection = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: chartWidget,
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                leaderboardWorkers,
                const SizedBox(height: 24),
                leaderboardProducts,
              ],
            ),
          ),
        ],
      );
    } else if (isTablet) {
      chartsAndLeaderboardsSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chartWidget,
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leaderboardWorkers),
              const SizedBox(width: 24),
              Expanded(child: leaderboardProducts),
            ],
          ),
        ],
      );
    } else {
      chartsAndLeaderboardsSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chartWidget,
          const SizedBox(height: 24),
          leaderboardWorkers,
          const SizedBox(height: 24),
          leaderboardProducts,
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
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
                        'dashboard.business_overview'.tr(),
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Performance ce mois',
                        style: TextStyle(
                          fontSize: 15, 
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF203A43)),
                    tooltip: 'Rafraîchir',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                      side: BorderSide(color: Colors.grey.shade200, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _fetchAnalytics();
                    },
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 20 : 32),
              metricsSection,
              SizedBox(height: isMobile ? 20 : 32),
              chartsAndLeaderboardsSection,
            ],
          ),
        ),
      ),
    );
  }

  String _formatChartValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  Widget _buildLegendIndicator(String name, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineChart(List<dynamic> timeline) {
    if (timeline.isEmpty) {
      return const Center(child: Text('Aucune donnée pour ce mois', style: TextStyle(color: Color(0xFF64748B))));
    }

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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade100,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= timeline.length) {
                  return const Text('');
                }
                final dateStr = timeline[index]['date_label'] as String;
                final day = dateStr.split('-').last;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 55,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatChartValue(value),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isRev = spot.barIndex == 0;
                return LineTooltipItem(
                  '${isRev ? 'Revenus' : 'Bénéfices'}: ${spot.y.toStringAsFixed(2)} DZD',
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: timeline.length > 1 ? (timeline.length - 1).toDouble() : 1.0,
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spotsRevenue,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          LineChartBarData(
            spots: spotsProfit,
            isCurved: true,
            color: AppColors.success,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.15),
                  AppColors.success.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(
    String title,
    List<dynamic> items,
    String Function(dynamic) getTitle,
    String Function(dynamic) getSubtitle,
    IconData defaultIcon,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(defaultIcon, color: const Color(0xFF64748B), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          items.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Aucune donnée', style: TextStyle(color: Color(0xFF64748B))),
                ))
              : Column(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final rank = index + 1;
                    final name = getTitle(item);

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.transparent,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Rank Badge
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? const Color(0xFFFBBF24) // Gold
                                      : rank == 2
                                          ? const Color(0xFF94A3B8) // Silver
                                          : rank == 3
                                              ? const Color(0xFFB45309) // Bronze
                                              : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: rank <= 3 ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                                child: Text(
                                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            getSubtitle(item),
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconBg;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconBg,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.2) : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.05 : 0.02),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
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
    );
  }
}
