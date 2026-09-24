import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chart_data.dart';
import '../models/dashboard.dart';
import '../models/insight.dart';
import '../models/recurring_payment.dart';
import 'api_provider.dart';

// Read-only analytics endpoints. autoDispose so they refetch when a screen
// re-subscribes; call ref.invalidate(...) to force a refresh after edits.

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) async {
  return ref.watch(apiClientProvider).getDashboard();
});

final chartsProvider = FutureProvider.autoDispose<ChartData>((ref) async {
  return ref.watch(apiClientProvider).getCharts();
});

final insightsProvider = FutureProvider.autoDispose<List<Insight>>((ref) async {
  return ref.watch(apiClientProvider).getInsights();
});

final spendingForecastProvider =
    FutureProvider.autoDispose<SpendingForecast>((ref) async {
  return ref.watch(apiClientProvider).predictSpending();
});

final recurringPaymentsProvider =
    FutureProvider.autoDispose<RecurringPaymentsResult>((ref) async {
  return ref.watch(apiClientProvider).getRecurringPayments();
});

/// Last-6-months totals for one category (line/bar trends).
final categoryTrendProvider = FutureProvider.autoDispose
    .family<List<MonthlyTotal>, String>((ref, category) async {
  return ref.watch(apiClientProvider).getTrends(category);
});
