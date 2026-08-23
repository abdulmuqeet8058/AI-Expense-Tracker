import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../theme.dart';
import '../models/chart_data.dart';
import '../providers/analytics_provider.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/section_header.dart';
import '../widgets/summary_card.dart';

final _money =
    NumberFormat.currency(symbol: '$kDefaultCurrencySymbol ', decimalDigits: 0);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = ref.watch(chartsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(chartsProvider);
          await ref.read(chartsProvider.future);
        },
        child: charts.when(
          loading: () => ListView(
            children: const [
              SizedBox(height: 12),
              LoadingShimmer(itemCount: 5)
            ],
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.show_chart, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Could not load analytics'),
                    const SizedBox(height: 4),
                    Text('$e',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          data: (data) => _content(context, data),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ChartData data) {
    final total = data.byCategory.fold<double>(0, (s, c) => s + c.total);
    final sortedCats = [...data.byCategory]
      ..sort((a, b) => b.total.compareTo(a.total));
    final avgDay = data.daily.isEmpty
        ? 0.0
        : data.daily.fold<double>(0, (s, d) => s + d.total) / data.daily.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 96),
      children: [
        _summaryRow(
          total: total,
          topCategory: sortedCats.isEmpty ? '—' : sortedCats.first.category,
          avgDay: avgDay,
        ),
        const SizedBox(height: 20),
        _padded(const SectionHeader(title: 'Daily spending')),
        const SizedBox(height: 8),
        _card(_lineChart(data.daily)),
        const SizedBox(height: 20),
        _padded(const SectionHeader(title: 'Monthly comparison')),
        const SizedBox(height: 8),
        _card(_barChart(data.monthly)),
        const SizedBox(height: 20),
        _padded(const SectionHeader(title: 'Spending by category')),
        const SizedBox(height: 8),
        _card(_pieChart(sortedCats, total)),
      ],
    );
  }

  Widget _summaryRow({
    required double total,
    required String topCategory,
    required double avgDay,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 168,
              child: SummaryCard(
                title: 'Total spent',
                value: _money.format(total),
                icon: Icons.payments_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 168,
              child: SummaryCard(
                title: 'Top category',
                value: topCategory,
                icon: Icons.emoji_events_outlined,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 168,
              child: SummaryCard(
                title: 'Avg / day',
                value: _money.format(avgDay),
                icon: Icons.trending_up,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

  Widget _card(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _lineChart(List<DailyTotal> daily) {
    if (daily.isEmpty) return _placeholder('No daily data yet');
    final maxY = daily.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    final top = maxY <= 0 ? 10.0 : maxY * 1.2;
    final step = (daily.length / 6).ceil().clamp(1, 9999);
    final spots = [
      for (var i = 0; i < daily.length; i++)
        FlSpot(i.toDouble(), daily[i].total),
    ];

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: top,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: top / 4,
                getTitlesWidget: (v, m) => Text(_short(v),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, m) {
                  final i = v.round();
                  if (i < 0 || i >= daily.length || i % step != 0) {
                    return const SizedBox.shrink();
                  }
                  final dt = daily[i].dateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(dt != null ? DateFormat('d/M').format(dt) : '',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barChart(List<MonthlyTotal> monthly) {
    if (monthly.isEmpty) return _placeholder('No monthly data yet');
    final maxY = monthly.fold<double>(0, (m, x) => x.total > m ? x.total : m);
    final top = maxY <= 0 ? 10.0 : maxY * 1.25;

    return SizedBox(
      height: 210,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: top / 4,
                getTitlesWidget: (v, m) => Text(_short(v),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (v, m) {
                  final i = v.round();
                  if (i < 0 || i >= monthly.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_monthLabel(monthly[i].month),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < monthly.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: monthly[i].total,
                    color: AppColors.accent,
                    width: 16,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _pieChart(List<CategoryTotal> sorted, double total) {
    if (sorted.isEmpty) return _placeholder('No category data yet');
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              startDegreeOffset: -90,
              sections: [
                for (final c in sorted)
                  PieChartSectionData(
                    value: c.total,
                    color: categoryColor(c.category),
                    radius: 58,
                    title: total <= 0
                        ? ''
                        : '${(c.total / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [for (final c in sorted) _legendDot(c.category)],
        ),
      ],
    );
  }

  Widget _legendDot(String category) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: categoryColor(category), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(category, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _placeholder(String message) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, color: Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

String _short(num v) {
  final a = v.abs();
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1)}k';
  return v.toStringAsFixed(0);
}

String _monthLabel(String m) {
  final dt = DateTime.tryParse(m.length == 7 ? '$m-01' : m);
  if (dt != null) return DateFormat('MMM').format(dt);
  return m.length > 3 ? m.substring(m.length - 3) : m;
}
