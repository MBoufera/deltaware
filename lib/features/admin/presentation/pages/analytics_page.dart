import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import '../bloc/analytics/analytics_bloc.dart';
import '../bloc/analytics/analytics_event.dart';
import '../bloc/analytics/analytics_state.dart';
import '../../../../core/widgets/permission_guard.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canViewReports.key,
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
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Du ${state.fromDate.toString().split(' ')[0]} au ${state.toDate.toString().split(' ')[0]}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
        Row(
          children: [
            ToggleButtons(
              isSelected: [
                state.period == 'today',
                state.period == 'week',
                state.period == 'month',
                state.period == 'year',
              ],
              onPressed: (index) {
                const periods = ['today', 'week', 'month', 'year'];
                context.read<AnalyticsBloc>().add(
                  LoadDashboard(period: periods[index]),
                );
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: const Color(0xFF203A43),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Jour'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Semaine'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Mois'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Année'),
                ),
              ],
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text('Personnalisé'),
              style: ElevatedButton.styleFrom(
                backgroundColor: state.period == 'custom'
                    ? const Color(0xFF203A43)
                    : Colors.white,
                foregroundColor: state.period == 'custom'
                    ? Colors.white
                    : const Color(0xFF203A43),
              ),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(
                    start: state.fromDate,
                    end: state.toDate,
                  ),
                );
                if (range != null && context.mounted) {
                  context.read<AnalyticsBloc>().add(
                    ChangeDateRange(from: range.start, to: range.end),
                  );
                }
              },
            ),
          ],
        ),
      ],
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
            icon: Icons.attach_money,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _MetricCard(
            title: 'Bénéfice Brut',
            value:
                '${(summary['gross_profit'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD',
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _MetricCard(
            title: 'Nombre de Ventes',
            value: (summary['sales_count'] ?? 0).toString(),
            icon: Icons.receipt_long,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _MetricCard(
            title: 'Marge %',
            value:
                '${(summary['margin_percent'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
            icon: Icons.percent,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineChart(List<dynamic> timeline) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Évolution des Revenus & Bénéfices',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (timeline.isEmpty)
            const Expanded(child: Center(child: Text('Aucune donnée')))
          else
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= timeline.length) {
                            return const Text('');
                          }
                          final dateStr =
                              timeline[index]['date_label'] as String;
                          final parts = dateStr.split('-');
                          final display = parts.length == 3
                              ? '${parts[2]}/${parts[1]}'
                              : dateStr;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              display,
                              style: const TextStyle(fontSize: 10),
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
                  borderData: FlBorderData(show: false),
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
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
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
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha: 0.1),
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

  Widget _buildCategoryPieChart(List<dynamic> categories) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventes par Catégorie',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (categories.isEmpty)
            const Expanded(child: Center(child: Text('Aucune donnée')))
          else
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: categories.asMap().entries.map((e) {
                    return PieChartSectionData(
                      color: colors[e.key % colors.length],
                      value: (e.value['revenue_ht'] as num).toDouble(),
                      title: e.value['category_name'],
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
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
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          items.isEmpty
              ? const Text('Aucune donnée')
              : Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1A2A32),
                            child: Text(
                              getTitle(item).substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            getTitle(item),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            getSubtitle(item),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
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

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
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
    );
  }
}
