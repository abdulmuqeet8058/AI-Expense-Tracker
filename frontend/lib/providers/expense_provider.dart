import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../services/api_client.dart';
import '../services/local_cache.dart';
import 'api_provider.dart';

/// Server-side query for the expenses list. Screens build a fresh instance and
/// hand it to [ExpenseNotifier.applyFilter].
class ExpenseFilter {
  final String? category;
  final DateTime? start;
  final DateTime? end;
  final String? search;
  final bool? isIncome;
  final String sort;

  const ExpenseFilter({
    this.category,
    this.start,
    this.end,
    this.search,
    this.isIncome,
    this.sort = '-date',
  });

  bool get isEmpty =>
      category == null &&
      start == null &&
      end == null &&
      (search == null || search!.isEmpty) &&
      isIncome == null;

  ExpenseFilter copyWith({
    String? category,
    DateTime? start,
    DateTime? end,
    String? search,
    bool? isIncome,
    String? sort,
    bool clearCategory = false,
    bool clearStart = false,
    bool clearEnd = false,
    bool clearSearch = false,
    bool clearIsIncome = false,
  }) {
    return ExpenseFilter(
      category: clearCategory ? null : (category ?? this.category),
      start: clearStart ? null : (start ?? this.start),
      end: clearEnd ? null : (end ?? this.end),
      search: clearSearch ? null : (search ?? this.search),
      isIncome: clearIsIncome ? null : (isIncome ?? this.isIncome),
      sort: sort ?? this.sort,
    );
  }
}

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final ApiClient _api;
  final LocalCache _cache;

  ExpenseFilter _filter = const ExpenseFilter();
  ExpenseFilter get filter => _filter;

  ExpenseNotifier(this._api, this._cache)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final items = await _api.getExpenses(
        category: _filter.category,
        start: _filter.start,
        end: _filter.end,
        search: _filter.search,
        isIncome: _filter.isIncome,
        sort: _filter.sort,
        limit: 200,
      );
      state = AsyncValue.data(items);
      await _cache.saveExpenses(items);
    } catch (e, st) {
      // offline / server down -> show cached list if we have one
      final cached = _cache.readExpenses();
      if (cached.isNotEmpty && _filter.isEmpty) {
        state = AsyncValue.data(cached);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> applyFilter(ExpenseFilter filter) async {
    _filter = filter;
    await refresh();
  }

  void clearFilter() {
    _filter = const ExpenseFilter();
    refresh();
  }

  /// Passing a null [category] lets the backend auto-categorize via ML.
  Future<Expense> add({
    required double amount,
    required String description,
    String? category,
    String? subCategory,
    DateTime? date,
    String paymentMethod = 'cash',
    Location? location,
    String? receiptUrl,
    bool isIncome = false,
  }) async {
    final created = await _api.createExpense(
      amount: amount,
      description: description,
      category: category,
      subCategory: subCategory,
      date: date,
      paymentMethod: paymentMethod,
      location: location,
      receiptUrl: receiptUrl,
      isIncome: isIncome,
    );
    final current = [created, ...(state.value ?? const <Expense>[])];
    state = AsyncValue.data(current);
    await _cache.saveExpenses(current);
    return created;
  }

  Future<Expense> update(Expense expense) async {
    final updated = await _api.updateExpense(
      expense.id,
      amount: expense.amount,
      description: expense.description,
      category: expense.category,
      subCategory: expense.subCategory,
      date: expense.date,
      paymentMethod: expense.paymentMethod,
      location: expense.location,
      receiptUrl: expense.receiptUrl,
      isIncome: expense.isIncome,
    );
    final current = [...(state.value ?? const <Expense>[])];
    final idx = current.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      current[idx] = updated;
    } else {
      current.insert(0, updated);
    }
    state = AsyncValue.data(current);
    await _cache.saveExpenses(current);
    return updated;
  }

  Future<void> delete(String id) async {
    await _api.deleteExpense(id);
    final current = [...(state.value ?? const <Expense>[])]
      ..removeWhere((e) => e.id == id);
    state = AsyncValue.data(current);
    await _cache.saveExpenses(current);
  }
}

final expensesProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<Expense>>>((ref) {
  return ExpenseNotifier(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});
