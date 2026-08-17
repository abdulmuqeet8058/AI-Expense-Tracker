import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../theme.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_shimmer.dart';

final _money = NumberFormat.currency(symbol: '$kDefaultCurrencySymbol ', decimalDigits: 0);

enum _Sort { newest, oldest, highest, lowest }

extension on _Sort {
  String get label => switch (this) {
        _Sort.newest => 'Newest first',
        _Sort.oldest => 'Oldest first',
        _Sort.highest => 'Amount: high to low',
        _Sort.lowest => 'Amount: low to high',
      };
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _category;
  DateTimeRange? _range;
  _Sort _sort = _Sort.newest;

  // ids the user just swiped away; hidden immediately so Dismissible doesn't
  // trip over an item that's still in the provider list until the API returns.
  final _removing = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Expense> _apply(List<Expense> items) {
    final q = _search.trim().toLowerCase();
    final out = items.where((e) {
      if (_removing.contains(e.id)) return false;
      if (q.isNotEmpty && !'${e.description} ${e.category ?? ''}'.toLowerCase().contains(q)) {
        return false;
      }
      if (_category != null && e.category != _category) return false;
      if (_range != null) {
        final d = DateUtils.dateOnly(e.date);
        if (d.isBefore(DateUtils.dateOnly(_range!.start)) ||
            d.isAfter(DateUtils.dateOnly(_range!.end))) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sort) {
      case _Sort.newest:
        out.sort((a, b) => b.date.compareTo(a.date));
      case _Sort.oldest:
        out.sort((a, b) => a.date.compareTo(b.date));
      case _Sort.highest:
        out.sort((a, b) => b.amount.compareTo(a.amount));
      case _Sort.lowest:
        out.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return out;
  }

  bool get _hasFilters =>
      _search.isNotEmpty || _category != null || _range != null;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _searchCtrl.clear();
      _category = null;
      _range = null;
    });
  }

  Future<void> _delete(Expense e) async {
    setState(() => _removing.add(e.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(expensesProvider.notifier).delete(e.id);
      if (!mounted) return;
      setState(() => _removing.remove(e.id));
      messenger.showSnackBar(SnackBar(content: Text('Deleted "${e.description}"')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _removing.remove(e.id)); // put it back
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete that. Try again.")),
      );
    }
  }

  Future<bool> _confirmDelete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('"${e.description}" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: Icon(_range == null ? Icons.date_range_outlined : Icons.event_available),
            onPressed: _pickRange,
          ),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in _Sort.values)
                PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _searchField(),
          _categoryFilter(),
          if (_range != null || _hasFilters) _activeFilters(),
          Expanded(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LoadingShimmer(),
              ),
              error: (e, _) => _errorView(e),
              data: (all) {
                final items = _apply(all);
                if (items.isEmpty) {
                  return EmptyState(
                    icon: _hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
                    title: all.isEmpty ? 'No expenses yet' : 'Nothing matches',
                    message: all.isEmpty
                        ? 'Tap the + button to log your first expense.'
                        : 'Try a different search or clear your filters.',
                    actionLabel: _hasFilters ? 'Clear filters' : null,
                    onAction: _hasFilters ? _clearFilters : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(expensesProvider.notifier).refresh(),
                  child: Column(
                    children: [
                      _summaryBar(items),
                      Expanded(child: _list(items)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search description or category',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _search = '';
                    _searchCtrl.clear();
                  }),
                ),
        ),
      ),
    );
  }

  Widget _categoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _AllChip(
            selected: _category == null,
            onTap: () => setState(() => _category = null),
          ),
          const SizedBox(width: 8),
          for (final c in kCategories) ...[
            CategoryChip(
              category: c,
              selected: _category == c,
              onTap: () => setState(() => _category = _category == c ? null : c),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _activeFilters() {
    final chips = <Widget>[];
    if (_range != null) {
      final f = DateFormat('d MMM');
      chips.add(InputChip(
        label: Text('${f.format(_range!.start)} – ${f.format(_range!.end)}'),
        onDeleted: () => setState(() => _range = null),
      ));
    }
    if (chips.isEmpty && !_hasFilters) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 4, children: chips),
          ),
          if (_hasFilters)
            TextButton(onPressed: _clearFilters, child: const Text('Clear')),
        ],
      ),
    );
  }

  Widget _summaryBar(List<Expense> items) {
    var spent = 0.0;
    var income = 0.0;
    for (final e in items) {
      if (e.isIncome) {
        income += e.amount;
      } else {
        spent += e.amount;
      }
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Text('${items.length} ${items.length == 1 ? 'item' : 'items'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          if (income > 0) ...[
            Text('+${_money.format(income)}',
                style: const TextStyle(
                    color: AppColors.income, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
          ],
          Text('-${_money.format(spent)}',
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _list(List<Expense> items) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _tile(items[i]),
    );
  }

  Widget _tile(Expense e) {
    final color = categoryColor(e.category);
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(e),
      onDismissed: (_) => _delete(e),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetails(e),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha:0.15),
                  child: Icon(categoryIcon(e.category), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${e.category ?? 'Uncategorized'} · ${DateFormat('d MMM').format(e.date)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${e.isIncome ? '+' : '-'}${_money.format(e.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: e.isIncome ? AppColors.income : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(Expense e) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final color = categoryColor(e.category);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha:0.15),
                      child: Icon(categoryIcon(e.category), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.description,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      '${e.isIncome ? '+' : '-'}${_money.format(e.amount)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: e.isIncome ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow('Category', e.category ?? 'Uncategorized'),
                _detailRow('Date', DateFormat('EEEE, d MMMM yyyy').format(e.date)),
                _detailRow('Payment', e.paymentMethod),
                _detailRow('Type', e.isIncome ? 'Income' : 'Expense'),
                if (e.confidenceScore != null)
                  _detailRow('ML confidence',
                      '${(_asPercent(e.confidenceScore!)).toStringAsFixed(0)}%'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    onPressed: () async {
                      Navigator.pop(context);
                      if (await _confirmDelete(e)) {
                        setState(() => _removing.add(e.id));
                        await _delete(e);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _errorView(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Could not load expenses',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$error',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ref.read(expensesProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// confidence can come back as 0-1 or already a percentage; normalize to %.
double _asPercent(double v) => v <= 1 ? v * 100 : v;

class _AllChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _AllChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const c = AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c : c.withValues(alpha:0.12),
            borderRadius: BorderRadius.circular(20),
            border: selected ? null : Border.all(color: c.withValues(alpha:0.25)),
          ),
          child: Text(
            'All',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : c,
            ),
          ),
        ),
      ),
    );
  }
}
