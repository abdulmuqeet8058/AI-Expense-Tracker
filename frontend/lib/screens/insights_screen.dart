import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
// import '../models/expense.dart';
import '../models/insight.dart';
import '../models/recurring_payment.dart';
import '../providers/analytics_provider.dart';
// import '../providers/expense_provider.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/insight_banner.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/section_header.dart';

final _number = NumberFormat('#,##0', 'en_US');

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(spendingForecastProvider);
    final insights = ref.watch(insightsProvider);
    final recurring = ref.watch(recurringPaymentsProvider);
    // final expenses = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Insights')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(spendingForecastProvider);
          ref.invalidate(insightsProvider);
          ref.invalidate(recurringPaymentsProvider);
          // await ref.read(expensesProvider.notifier).refresh();
          await Future.wait([
            ref.read(insightsProvider.future),
            ref.read(spendingForecastProvider.future),
            ref.read(recurringPaymentsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _IntelligenceHeader(),
            // const SizedBox(height: 20),
            // _ConfidenceCard(expenses: expenses),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Recurring payments',
              subtitle: 'Subscriptions and bills detected from your history',
              icon: Icons.event_repeat_rounded,
            ),
            const SizedBox(height: 10),
            _RecurringPaymentsCard(result: recurring),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Spending forecast',
              subtitle: 'A category-level projection for the coming month',
              icon: Icons.trending_up_rounded,
            ),
            const SizedBox(height: 10),
            _ForecastCard(forecast: forecast),
            const SizedBox(height: 24),
            ..._insightContent(insights),
          ],
        ),
      ),
    );
  }

  List<Widget> _insightContent(AsyncValue<List<Insight>> async) {
    return async.when(
      loading: () => const [LoadingShimmer(itemCount: 3)],
      error: (_, __) => const [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Insights unavailable',
          message: 'Pull down to try loading them again.',
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return const [
            EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Building your profile',
              message: 'Add more expenses to unlock personalized insights.',
            ),
          ];
        }
        final alerts = items.where(_isAlert).toList();
        final tips = items.where((item) => !_isAlert(item)).toList();
        return [
          if (alerts.isNotEmpty) ...[
            const SectionHeader(
              title: 'Smart alerts',
              subtitle: 'Unusual activity and budget risks',
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 10),
            for (final alert in alerts) ...[
              InsightBanner(insight: alert),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
          ],
          if (tips.isNotEmpty) ...[
            const SectionHeader(
              title: 'Personalized insights',
              subtitle: 'Patterns found in your financial activity',
              icon: Icons.tips_and_updates_outlined,
            ),
            const SizedBox(height: 10),
            for (final tip in tips) ...[
              InsightBanner(insight: tip),
              const SizedBox(height: 10),
            ],
          ],
        ];
      },
    );
  }
}

class _IntelligenceHeader extends StatelessWidget {
  const _IntelligenceHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E5CCB), Color(0xFF00A86B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your financial intelligence center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Machine-learning models turn your expense history into recurring-payment predictions, forecasts, alerts, and useful patterns.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/*
class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.expenses});

  final AsyncValue<List<Expense>> expenses;

  @override
  Widget build(BuildContext context) {
    final scored = (expenses.value ?? const <Expense>[])
        .where((expense) => expense.confidenceScore != null)
        .toList();
    final average = scored.isEmpty
        ? null
        : scored
                .map((expense) => _percentage(expense.confidenceScore!))
                .reduce((a, b) => a + b) /
            scored.length;
    final color = average == null
        ? AppColors.accent
        : average >= 80
            ? AppColors.success
            : average >= 60
                ? AppColors.warning
                : AppColors.danger;

    return _Card(
      child: Row(
        children: [
          SizedBox(
            height: 62,
            width: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: average == null ? 0 : (average / 100).clamp(0, 1),
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Icon(
                  average == null ? Icons.psychology_outlined : null,
                  color: color,
                  size: 24,
                ),
                if (average != null)
                  Text(
                    '${average.round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Categorization confidence',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  average == null
                      ? 'AI confidence appears after automatically categorized expenses.'
                      : 'Average confidence across ${scored.length} AI-categorized expense${scored.length == 1 ? '' : 's'}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
*/

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final AsyncValue<SpendingForecast> forecast;

  @override
  Widget build(BuildContext context) {
    return forecast.when(
      loading: () => const _Card(
        child: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const _Card(
        child: Text('The spending forecast is unavailable right now.'),
      ),
      data: (result) {
        if (result.predictions.isEmpty) {
          return const _Card(
            child: Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, color: AppColors.accent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add expenses over several months to build a spending forecast.',
                  ),
                ),
              ],
            ),
          );
        }

        final entries = result.predictions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maximum = entries.first.value;
        final modelLabel = result.modelMode == 'ml'
            ? 'Trained XGBoost model'
            : result.modelMode == 'mixed'
                ? 'XGBoost + history estimate'
                : 'History estimate';
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _periodLabel(result.forecastPeriod),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${result.currency} ${_number.format(result.totalPredicted)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      modelLabel,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final entry in entries.take(5)) ...[
                _ForecastRow(
                  category: entry.key,
                  value: entry.value,
                  maximum: maximum,
                  currency: result.currency,
                ),
                const SizedBox(height: 11),
              ],
              Text(
                'Uses ${result.monthsAnalyzed} months of history. Forecasts are estimates, not guarantees.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecurringPaymentsCard extends StatelessWidget {
  const _RecurringPaymentsCard({required this.result});

  final AsyncValue<RecurringPaymentsResult> result;

  @override
  Widget build(BuildContext context) {
    return result.when(
      loading: () => const _Card(
        child: SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const _Card(
        child: Text('Recurring-payment analysis is unavailable right now.'),
      ),
      data: (data) {
        if (data.payments.isEmpty) {
          return const _Card(
            child: Row(
              children: [
                Icon(Icons.manage_search_rounded, color: AppColors.accent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add at least three matching weekly or monthly payments. AI will detect the pattern automatically.',
                  ),
                ),
              ],
            ),
          );
        }

        final summary = data.summary;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.currency} ${_number.format(summary.monthlyCommitment)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'estimated monthly commitment',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricPill(
                    icon: Icons.repeat_rounded,
                    label: '${summary.detectedCount} detected',
                  ),
                  _MetricPill(
                    icon: Icons.calendar_month_outlined,
                    label: '${summary.upcoming30Days} due in 30 days',
                  ),
                  if (summary.priceIncreases > 0)
                    _MetricPill(
                      icon: Icons.trending_up_rounded,
                      label:
                          '${summary.priceIncreases} price increase${summary.priceIncreases == 1 ? '' : 's'}',
                      isWarning: true,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              for (final payment in data.payments) ...[
                _RecurringPaymentRow(
                  payment: payment,
                  currency: summary.currency,
                ),
                if (payment != data.payments.last) const Divider(height: 1),
              ],
              const SizedBox(height: 4),
              Text(
                'Detected from similar descriptions and payment timing. Predictions improve as more history is added.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecurringPaymentRow extends StatelessWidget {
  const _RecurringPaymentRow({
    required this.payment,
    required this.currency,
  });

  final RecurringPayment payment;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(payment.category);
    final confidence = _percentage(payment.confidence).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon(payment.category), color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${payment.cadence} · ${payment.occurrenceCount} payments · $confidence% confidence',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    Text(
                      _dueLabel(payment),
                      style: TextStyle(
                        color: payment.daysUntilDue <= 7
                            ? AppColors.warning
                            : AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (payment.priceChangePercent != null)
                      Text(
                        'Price up ${payment.priceChangePercent!.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 104),
            child: Text(
              '$currency ${_number.format(payment.expectedAmount)}',
              textAlign: TextAlign.end,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.danger : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({
    required this.category,
    required this.value,
    required this.maximum,
    required this.currency,
  });

  final String category;
  final double value;
  final double maximum;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$currency ${_number.format(value)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: maximum <= 0 ? 0 : (value / maximum).clamp(0, 1),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

bool _isAlert(Insight insight) {
  final severity = insight.severity.toLowerCase();
  return insight.type.toLowerCase() == 'anomaly' ||
      severity == 'warning' ||
      severity == 'critical' ||
      severity == 'danger';
}

double _percentage(double value) => value <= 1 ? value * 100 : value;

String _periodLabel(String value) {
  final parsed = DateTime.tryParse('$value-01');
  return parsed == null ? 'Next month' : DateFormat('MMMM yyyy').format(parsed);
}

String _dueLabel(RecurringPayment payment) {
  final date = DateFormat('MMM d').format(payment.nextExpectedDate.toLocal());
  if (payment.daysUntilDue < 0) {
    return 'Expected ${payment.daysUntilDue.abs()} days ago · $date';
  }
  if (payment.daysUntilDue == 0) return 'Expected today';
  if (payment.daysUntilDue == 1) return 'Expected tomorrow · $date';
  return 'Expected in ${payment.daysUntilDue} days · $date';
}
