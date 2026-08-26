import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../theme.dart';
import '../models/budget.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_progress.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_shimmer.dart';

final _money =
    NumberFormat.currency(symbol: '$kDefaultCurrencySymbol ', decimalDigits: 0);

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  Set<String> _takenThisMonth(List<Budget> budgets) {
    final now = DateTime.now();
    return budgets
        .where((b) => b.month == now.month && b.year == now.year)
        .map((b) => b.category)
        .toSet();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetsProvider);
    final taken = _takenThisMonth(async.value ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            tooltip: 'New budget',
            icon: const Icon(Icons.add),
            onPressed: () => _openSheet(context, taken),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Could not load budgets',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.read(budgetsProvider.notifier).refresh(),
        ),
        data: (budgets) {
          if (budgets.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No budgets yet',
              message:
                  'Set a monthly limit per category and track how much is left.',
              actionLabel: 'Create budget',
              onAction: () => _openSheet(context, taken),
            );
          }
          final sorted = [...budgets]
            ..sort((a, b) => b.fraction.compareTo(a.fraction));
          return RefreshIndicator(
            onRefresh: () => ref.read(budgetsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _overview(context, budgets),
                const SizedBox(height: 16),
                for (final b in sorted) _budgetCard(context, ref, b),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overview(BuildContext context, List<Budget> budgets) {
    final limit = budgets.fold<double>(0, (s, b) => s + b.monthlyLimit);
    final spent = budgets.fold<double>(0, (s, b) => s + b.currentSpent);
    final remaining = limit - spent;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF00A344)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total budget this month',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(_money.format(limit),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              _overviewStat('Spent', _money.format(spent)),
              Container(width: 1, height: 34, color: Colors.white24),
              _overviewStat(
                remaining >= 0 ? 'Remaining' : 'Over by',
                _money.format(remaining.abs()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _budgetCard(BuildContext context, WidgetRef ref, Budget b) {
    final color = categoryColor(b.category);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(categoryIcon(b.category), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.category,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                        DateFormat('MMMM yyyy')
                            .format(DateTime(b.year, b.month)),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    _openSheet(context, const {}, edit: b);
                  } else if (v == 'delete') {
                    _confirmDelete(context, ref, b);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          BudgetProgress(
            label: 'Alert at ${b.alertThreshold.toStringAsFixed(0)}%',
            spent: b.currentSpent,
            limit: b.monthlyLimit,
            alertThreshold: b.alertThreshold,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Budget b) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text('The budget for ${b.category} will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(budgetsProvider.notifier).delete(b.id);
      messenger.showSnackBar(const SnackBar(content: Text('Budget deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openSheet(BuildContext context, Set<String> taken, {Budget? edit}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BudgetSheet(taken: taken, edit: edit),
      ),
    );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  final Set<String> taken;
  final Budget? edit;
  const _BudgetSheet({required this.taken, this.edit});

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late String? _category;
  late double _threshold;
  final _limitCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.edit != null;

  List<String> get _available {
    if (_isEdit) return kCategories;
    final free = kCategories.where((c) => !widget.taken.contains(c)).toList();
    return free;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _threshold = e?.alertThreshold ?? 80;
    _category =
        e?.category ?? (_available.isNotEmpty ? _available.first : null);
    if (e != null) _limitCtrl.text = e.monthlyLimit.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final limit = double.tryParse(_limitCtrl.text.trim());
    if (_category == null) {
      setState(() => _error = 'Pick a category');
      return;
    }
    if (limit == null || limit <= 0) {
      setState(() => _error = 'Enter a monthly limit greater than 0');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(budgetsProvider.notifier);
    final now = DateTime.now();
    try {
      if (_isEdit) {
        await notifier.update(
          widget.edit!.id,
          category: _category,
          monthlyLimit: limit,
          alertThreshold: _threshold,
        );
      } else {
        await notifier.create(
          category: _category!,
          monthlyLimit: limit,
          month: now.month,
          year: now.year,
          alertThreshold: _threshold,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_available.isEmpty && !_isEdit) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text('Every category already has a budget this month.',
            textAlign: TextAlign.center),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEdit ? 'Edit budget' : 'New budget',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in _available)
                DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(categoryIcon(c), size: 18, color: categoryColor(c)),
                      const SizedBox(width: 10),
                      Text(c),
                    ],
                  ),
                ),
            ],
            onChanged: _isEdit ? null : (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _limitCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly limit',
              prefixText: '$kDefaultCurrencySymbol ',
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('Alert threshold'),
              const Spacer(),
              Text('${_threshold.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: _threshold,
            min: 50,
            max: 100,
            divisions: 10,
            label: '${_threshold.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _threshold = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Create budget'),
            ),
          ),
        ],
      ),
    );
  }
}
