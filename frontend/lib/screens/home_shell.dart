import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/expense.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../theme.dart';
import 'add_expense_screen.dart';
import 'expenses_screen.dart';

final _number = NumberFormat('#,##0', 'en_US');

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [_OverviewScreen(), ExpensesScreen()];

  Future<void> _addTransaction() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
        ],
      ),
    );
  }
}

class _OverviewScreen extends ConsumerWidget {
  const _OverviewScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final expenses = ref.watch(expensesProvider);
    final name = user?.fullName.trim() ?? '';
    final firstName = name.isEmpty ? 'there' : name.split(' ').first;
    final currency = user?.currency ?? kDefaultCurrency;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(expensesProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          firstName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Log out',
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/auth', (_) => false);
                      }
                    },
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _AiComingSoonBanner(),
              const SizedBox(height: 24),
              ...expenses.when(
                data: (items) => _content(context, items, currency),
                loading: () => const [
                  SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, _) => [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Could not load transactions: $error'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    List<Expense> items,
    String currency,
  ) {
    final now = DateTime.now();
    final current = items.where(
      (item) => item.date.year == now.year && item.date.month == now.month,
    );
    final spent = current
        .where((item) => !item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final income = current
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);

    return [
      Row(
        children: [
          Expanded(
            child: _AmountCard(
              label: 'Spent this month',
              amount: spent,
              currency: currency,
              icon: Icons.south_west_rounded,
              color: AppColors.expense,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AmountCard(
              label: 'Income this month',
              amount: income,
              currency: currency,
              icon: Icons.north_east_rounded,
              color: AppColors.income,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _AmountCard(
        label: 'Net balance this month',
        amount: income - spent,
        currency: currency,
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.accent,
      ),
      const SizedBox(height: 28),
      Text(
        'Recent transactions',
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (items.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Tap Add to record your first transaction.'),
          ),
        )
      else
        ...items
            .take(5)
            .map((item) => _TransactionRow(item: item, currency: currency)),
    ];
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

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 14),
            Text(
              '$currency ${_number.format(amount)}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item, required this.currency});

  final Expense item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(item.category);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(categoryIcon(item.category), color: color),
        ),
        title: Text(item.description),
        subtitle: Text(
          '${item.category ?? 'Miscellaneous'} · '
          '${DateFormat('d MMM').format(item.date)}',
        ),
        trailing: Text(
          '${item.isIncome ? '+' : '-'}$currency ${_number.format(item.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: item.isIncome ? AppColors.income : AppColors.expense,
          ),
        ),
      ),
    );
  }
}
