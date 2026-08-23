import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../services/api_client.dart';
import 'api_provider.dart';

class BudgetNotifier extends StateNotifier<AsyncValue<List<Budget>>> {
  final ApiClient _api;

  BudgetNotifier(this._api) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final items = await _api.getBudgets();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Budget> create({
    required String category,
    required double monthlyLimit,
    required int month,
    required int year,
    double alertThreshold = 80,
  }) async {
    final budget = await _api.createBudget(
      category: category,
      monthlyLimit: monthlyLimit,
      month: month,
      year: year,
      alertThreshold: alertThreshold,
    );
    final current = [...(state.value ?? const <Budget>[])];
    final idx = current.indexWhere((b) => b.id == budget.id);
    if (idx >= 0) {
      current[idx] = budget;
    } else {
      current.add(budget);
    }
    state = AsyncValue.data(current);
    return budget;
  }

  Future<Budget> update(
    String id, {
    String? category,
    double? monthlyLimit,
    int? month,
    int? year,
    double? alertThreshold,
  }) async {
    final budget = await _api.updateBudget(
      id,
      category: category,
      monthlyLimit: monthlyLimit,
      month: month,
      year: year,
      alertThreshold: alertThreshold,
    );
    final current = [...(state.value ?? const <Budget>[])];
    final idx = current.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      current[idx] = budget;
    } else {
      current.add(budget);
    }
    state = AsyncValue.data(current);
    return budget;
  }

  Future<void> delete(String id) async {
    await _api.deleteBudget(id);
    final current = [...(state.value ?? const <Budget>[])]
      ..removeWhere((b) => b.id == id);
    state = AsyncValue.data(current);
  }
}

final budgetsProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<List<Budget>>>((ref) {
  return BudgetNotifier(ref.watch(apiClientProvider));
});

final budgetAlertsProvider =
    FutureProvider.autoDispose<List<Budget>>((ref) async {
  return ref.watch(apiClientProvider).getBudgetAlerts();
});
