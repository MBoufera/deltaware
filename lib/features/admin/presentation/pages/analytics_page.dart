import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../bloc/analytics/analytics_bloc.dart';
import '../bloc/analytics/analytics_event.dart';
import '../bloc/analytics/analytics_state.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../../features/store/presentation/bloc/store_state.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalyticsForCurrentStore();
    });
  }

  void _loadAnalyticsForCurrentStore() {
    final storeId = context.read<StoreBloc>().currentStoreId;
    context.read<AnalyticsBloc>().add(LoadDashboard(storeId: storeId));
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canViewReports.key,
      child: BlocListener<StoreBloc, StoreState>(
        listenWhen: (prev, curr) {
          final prevId = prev is StoresLoaded ? prev.selectedStore?.id : null;
          final currId = curr is StoresLoaded ? curr.selectedStore?.id : null;
          return prevId != currId;
        },
        listener: (context, state) {
          final storeId = context.read<StoreBloc>().currentStoreId;
          context.read<AnalyticsBloc>().add(LoadDashboard(storeId: storeId));
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          body: SafeArea(
            child: BlocBuilder<AnalyticsBloc, AnalyticsState>(
              builder: (context, state) {
                if (state is AnalyticsInitial || state is AnalyticsLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is AnalyticsError) {
                  return Center(child: Text('Error: ${state.message}'));
                } else if (state is AnalyticsLoaded) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, state),
                        const SizedBox(height: 32),
                        _buildKpiRow(state.summary),
                        const SizedBox(height: 32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildTimelineChart(state.timeline),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 3,
                              child: _buildCategoryPieChart(
                                state.categoryBreakdown,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildLeaderboard(
                                'Meilleurs Vendeurs',
                                state.topWorkers,
                                (w) => w['name'],
                                (w) =>
                                    '${(w['revenue_ht'] as num).toStringAsFixed(0)} DZD',
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: _buildLeaderboard(
                                'Top Produits',
                                state.topProducts,
                                (p) => p['name_fr'],
                                (p) => '${p['qty_sold']} unités',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AnalyticsLoaded state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analyses & Rapports',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2A32),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  'Du ${state.fromDate.toString().split(' ')[0]} au ${state.toDate.toString().split(' ')[0]}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildPillButton(context, 'Jour', state.period == 'today', 'today'),
                  _buildPillButton(context, 'Semaine', state.period == 'week', 'week'),
                  _buildPillButton(context, 'Mois', state.period == 'month', 'month'),
                  _buildPillButton(context, 'Année', state.period == 'year', 'year'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _CustomRangeButton(
              isSelected: state.period == 'custom',
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(
                    start: state.fromDate,
                    end: state.toDate,
                  ),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF203A43),
                          onPrimary: Colors.white,
                          onSurface: Color(0xFF1A2A32),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null && context.mounted) {
                  final storeId = context.read<StoreBloc>().currentStoreId;
                  context.read<AnalyticsBloc>().add(
                    ChangeDateRange(from: range.start, to: range.end, storeId: storeId),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPillButton(
    BuildContext context,
    String label,
    bool isSelected,
    String periodKey,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final storeId = context.read<StoreBloc>().currentStoreId;
          context.read<AnalyticsBloc>().add(
            LoadDashboard(period: periodKey, storeId: storeId),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF203A43) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiRow(Map<String, dynamic> summary) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Chiffre d\'Affaire HT',
            value:
                '${(summary['total_revenue_ht'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD',
            icon: Icons.payments_outlined,
            color: const Color(0xFF203A43),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _MetricCard(
            title: 'Bénéfice Brut',
            value:
                '${(summary['gross_profit'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _MetricCard(
            title: 'Nombre de Ventes',
            value: (summary['sales_count'] ?? 0).toString(),
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _MetricCard(
            title: 'Marge %',
            value:
                '${(summary['margin_percent'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
            icon: Icons.percent_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineChart(List<dynamic> timeline) {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
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
                  color: Color(0xFF1A2A32),
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem('Revenus', const Color(0xFF203A43)),
                  const SizedBox(width: 16),
                  _buildLegendItem('Bénéfices', const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (timeline.isEmpty)
            const Expanded(child: Center(child: Text('Aucune donnée')))
          else
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) =>
                          const Color(0xFF1A2A32).withValues(alpha: 0.9),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final value = touchedSpot.y.toStringAsFixed(2);
                          final prefix =
                              touchedSpot.barIndex == 0 ? 'Revenus: ' : 'Bénéfices: ';
                          return LineTooltipItem(
                            '$prefix$value DZD',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade100,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= timeline.length) {
                            return const SizedBox();
                          }
                          final dateStr =
                              timeline[index]['date_label'] as String;
                          final parts = dateStr.split('-');
                          final display = parts.length == 3
                              ? '${parts[2]}/${parts[1]}'
                              : dateStr;
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              display,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value >= 1000000
                                  ? '${(value / 1000000).toStringAsFixed(1)}M'
                                  : value >= 1000
                                      ? '${(value / 1000).toStringAsFixed(0)}k'
                                      : value.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
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
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                      left: const BorderSide(color: Colors.transparent),
                      right: const BorderSide(color: Colors.transparent),
                      top: const BorderSide(color: Colors.transparent),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: timeline
                          .asMap()
                          .entries
                          .map(
                            (e) => FlSpot(
                              e.key.toDouble(),
                              (e.value['revenue_ht'] as num).toDouble(),
                            ),
                          )
                          .toList(),
                      isCurved: true,
                      color: const Color(0xFF203A43),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF203A43).withValues(alpha: 0.15),
                            const Color(0xFF203A43).withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: timeline
                          .asMap()
                          .entries
                          .map(
                            (e) => FlSpot(
                              e.key.toDouble(),
                              (e.value['gross_profit'] as num).toDouble(),
                            ),
                          )
                          .toList(),
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.15),
                            const Color(0xFF10B981).withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPieChart(List<dynamic> categories) {
    final colors = [
      const Color(0xFF203A43),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF43F5E),
    ];

    return Container(
      height: 450,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventes par Catégorie',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2A32),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            const Expanded(child: Center(child: Text('Aucune donnée')))
          else
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 150,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                            sections: categories.asMap().entries.map((e) {
                              final color = colors[e.key % colors.length];
                              final value = (e.value['revenue_ht'] as num).toDouble();
                              return PieChartSectionData(
                                color: color,
                                value: value,
                                radius: 15,
                                showTitle: false,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        final color = colors[index % colors.length];
                        final name = item['category_name'] as String;
                        final value = (item['revenue_ht'] as num).toDouble();
                        final total = categories.fold<double>(
                          0.0,
                          (sum, c) => sum + (c['revenue_ht'] as num).toDouble(),
                        );
                        final pct = total > 0 ? (value / total) * 100 : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${value.toStringAsFixed(0)} DZD',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF203A43),
                                    ),
                                  ),
                                  Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2A32),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          items.isEmpty
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final rank = index + 1;

                    Color rankBgColor;
                    Color rankTextColor;
                    if (rank == 1) {
                      rankBgColor = const Color(0xFFFEF3C7);
                      rankTextColor = const Color(0xFFD97706);
                    } else if (rank == 2) {
                      rankBgColor = const Color(0xFFF1F5F9);
                      rankTextColor = const Color(0xFF475569);
                    } else if (rank == 3) {
                      rankBgColor = const Color(0xFFFFEDD5);
                      rankTextColor = const Color(0xFFC2410C);
                    } else {
                      rankBgColor = Colors.grey.shade100;
                      rankTextColor = Colors.grey.shade600;
                    }

                    return _LeaderboardRow(
                      rank: rank,
                      rankBgColor: rankBgColor,
                      rankTextColor: rankTextColor,
                      title: getTitle(item),
                      subtitle: getSubtitle(item),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatefulWidget {
  final int rank;
  final Color rankBgColor;
  final Color rankTextColor;
  final String title;
  final String subtitle;

  const _LeaderboardRow({
    required this.rank,
    required this.rankBgColor,
    required this.rankTextColor,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<_LeaderboardRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF203A43).withValues(alpha: 0.1)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.rankBgColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.rank}',
                style: TextStyle(
                  color: widget.rankTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              widget.subtitle,
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
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
                  ? widget.color.withValues(alpha: 0.2)
                  : Colors.grey.shade100,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.color, size: 30),
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
                    const SizedBox(height: 8),
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
    );
  }
}

class _CustomRangeButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomRangeButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CustomRangeButton> createState() => _CustomRangeButtonState();
}

class _CustomRangeButtonState extends State<_CustomRangeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? (_isHovered ? const Color(0xFF1E353D) : const Color(0xFF203A43))
        : (_isHovered ? Colors.grey.shade50 : Colors.white);

    final fgColor = widget.isSelected ? Colors.white : const Color(0xFF203A43);
    final borderColor = widget.isSelected ? Colors.transparent : Colors.grey.shade200;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isSelected ? 0.04 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 16,
                color: fgColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Personnalisé',
                style: TextStyle(
                  color: fgColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
