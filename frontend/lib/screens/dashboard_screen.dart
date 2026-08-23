import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
// The model file also declares a `BudgetProgress` (data holder); hide it so the
// name refers to the widget of the same name below.
import '../models/dashboard.dart' hide BudgetProgress;
import '../models/expense.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../theme.dart';
import '../widgets/budget_progress.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/summary_card.dart';
import 'categories_screen.dart';

final _nf = NumberFormat('#,##0', 'en_US');
String _money(num v, String currency) => '$currency ${_nf.format(v)}';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;
    final currency = user?.currency ?? kDefaultCurrency;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _header(context, ref, user?.fullName ?? '', user?.email ?? ''),
              const SizedBox(height: 20),
              ...dash.when(
                data: (d) => _content(context, d, currency),
                loading: () => const [
                  SizedBox(
                      height: 320,
                      child: Center(child: CircularProgressIndicator())),
                ],
                error: (e, _) => [
                  _ErrorBox(
                    message: _friendly(e),
                    onRetry: () => ref.invalidate(dashboardProvider),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait<void>([
      ref.refresh(dashboardProvider.future).then((_) {}),
      ref.read(expensesProvider.notifier).refresh(),
    ]);
  }

  Widget _header(
      BuildContext context, WidgetRef ref, String name, String email) {
    final first = name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
    final initials = _initials(name);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                first,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          offset: const Offset(0, 50),
          onSelected: (v) async {
            if (v == 'logout') {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/auth', (r) => false);
              }
            }
          },
          itemBuilder: (_) => [
            if (email.isNotEmpty)
              PopupMenuItem<String>(
                enabled: false,
                child: Text(email,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 10),
                Text('Log out'),
              ]),
            ),
          ],
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, Dashboard d, String currency) {
    return [
      Row(
        children: [
          Expanded(
            child: SummaryCard(
              title: 'Spent this month',
              value: _money(d.totalSpentMonth, currency),
              icon: Icons.south_west_rounded,
              color: AppColors.expense,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              title: 'Income this month',
              value: _money(d.totalIncomeMonth, currency),
              icon: Icons.north_east_rounded,
              color: AppColors.income,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SummaryCard(
        title: 'Net this month',
        value: _money(d.netMonth, currency),
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.accent,
      ),
      const SizedBox(height: 16),
      const _AiComingSoonBanner(),
      const SizedBox(height: 24),

      // Budgets
      const SectionHeader(title: 'Budgets'),
      const SizedBox(height: 12),
      if (d.budgetProgress.isEmpty)
        const _MiniEmpty(
          icon: Icons.savings_outlined,
          text: 'No budgets set. Add one from the Budget tab to track it here.',
        )
      else
        ...d.budgetProgress.map(
          (b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: BudgetProgress(
              label: b.category,
              spent: b.spent,
              limit: b.limit,
              currencySymbol: currency,
            ),
          ),
        ),
      const SizedBox(height: 24),

      // Top spending
      SectionHeader(
        title: 'Top spending',
        actionLabel: 'Details',
        onAction: () => _push(context, const CategoriesScreen()),
      ),
      const SizedBox(height: 8),
      if (d.topCategories.isEmpty)
        const _MiniEmpty(
          icon: Icons.pie_chart_outline,
          text: 'Spending by category shows up here once you add expenses.',
        )
      else
        ...d.topCategories.take(5).map(
              (c) => _CategoryTotalRow(
                category: c.category,
                amount: c.total,
                currency: currency,
              ),
            ),
      const SizedBox(height: 24),

      // Recent
      const SectionHeader(title: 'Recent activity'),
      const SizedBox(height: 8),
      if (d.recent.isEmpty)
        const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No expenses yet',
          message: 'Tap the + button to log your first expense.',
        )
      else
        ...d.recent.take(5).map(
              (e) => _RecentTile(expense: e, currency: currency),
            ),
    ];
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _AiComingSoonBanner extends StatelessWidget {
  const _AiComingSoonBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2979FF), Color(0xFF00A86B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'COMING IN THE NEXT PHASE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'AI-powered expense tracking',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Smart categorization and spending insights are coming soon.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

String _friendly(Object e) {
  final s = e.toString();
  return s.isEmpty ? 'Something went wrong' : s;
}

class _CategoryTotalRow extends StatelessWidget {
  const _CategoryTotalRow({
    required this.category,
    required this.amount,
    required this.currency,
  });

  final String category;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon(category), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(_money(amount, currency),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.expense, required this.currency});

  final Expense expense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final color = categoryColor(e.category);
    final amtColor = e.isIncome ? AppColors.income : AppColors.expense;
    final sign = e.isIncome ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon(e.category), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.description.isEmpty
                      ? (e.category ?? 'Expense')
                      : e.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.category ?? 'Uncategorized'} · ${DateFormat('MMM d').format(e.date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${_money(e.amount, currency)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: amtColor),
          ),
        ],
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  const _MiniEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
