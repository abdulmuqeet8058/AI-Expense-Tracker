import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/section_header.dart';

final _money =
    NumberFormat.currency(symbol: '$kDefaultCurrencySymbol ', decimalDigits: 0);

class _Slice {
  final String category;
  final double total;
  final int count;
  const _Slice(this.category, this.total, this.count);
}

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _thisMonth = true;
  int _touched = -1;

  bool _inScope(Expense e) {
    if (!_thisMonth) return true;
    final now = DateTime.now();
    return e.date.year == now.year && e.date.month == now.month;
  }

  List<_Slice> _slices(List<Expense> all) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final e in all) {
      if (e.isIncome || !_inScope(e)) continue;
      final c = e.category ?? 'Miscellaneous';
      totals[c] = (totals[c] ?? 0) + e.amount;
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final slices = totals.entries
        .map((e) => _Slice(e.key, e.value, counts[e.key] ?? 0))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: async.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Could not load data',
          message: '$e',
        ),
        data: (all) {
          final slices = _slices(all);
          final grand = slices.fold<double>(0, (s, e) => s + e.total);
          return RefreshIndicator(
            onRefresh: () => ref.read(expensesProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _scopeToggle(),
                const SizedBox(height: 16),
                if (slices.isEmpty)
                  const SizedBox(
                    height: 320,
                    child: EmptyState(
                      icon: Icons.pie_chart_outline,
                      title: 'Nothing to break down',
                      message: 'No spending recorded for this period yet.',
                    ),
                  )
                else ...[
                  SizedBox(height: 230, child: _pie(slices, grand)),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Breakdown'),
                  const SizedBox(height: 8),
                  for (var i = 0; i < slices.length; i++)
                    _breakdownRow(slices[i], grand, i == _touched),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scopeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
            value: true,
            label: Text('This Month'),
            icon: Icon(Icons.calendar_month)),
        ButtonSegment(
            value: false,
            label: Text('All Time'),
            icon: Icon(Icons.all_inclusive)),
      ],
      selected: {_thisMonth},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() {
        _thisMonth = s.first;
        _touched = -1;
      }),
    );
  }

  Widget _pie(List<_Slice> slices, double grand) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 62,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      response?.touchedSection == null) {
                    _touched = -1;
                  } else {
                    _touched = response!.touchedSection!.touchedSectionIndex;
                  }
                });
              },
            ),
            sections: [
              for (var i = 0; i < slices.length; i++)
                _section(i, slices[i], grand),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_thisMonth ? 'This month' : 'All time',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(_money.format(grand),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _section(int i, _Slice s, double grand) {
    final touched = i == _touched;
    final pct = grand <= 0 ? 0.0 : s.total / grand * 100;
    return PieChartSectionData(
      value: s.total,
      color: categoryColor(s.category),
      radius: touched ? 74 : 62,
      title: pct >= 7 ? '${pct.toStringAsFixed(0)}%' : '',
      titleStyle: TextStyle(
        fontSize: touched ? 15 : 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Widget _breakdownRow(_Slice s, double grand, bool active) {
    final color = categoryColor(s.category);
    final frac = grand <= 0 ? 0.0 : s.total / grand;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(categoryIcon(s.category), size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(_money.format(s.total),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(frac * 100).toStringAsFixed(1)}% · ${s.count} ${s.count == 1 ? 'txn' : 'txns'}',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
