import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/expense.dart';

/// Small Hive-backed cache so the Expenses list still renders when the
/// device is offline. We store the list as a single JSON string - simpler and
/// more forgiving than registering Hive type adapters for the models.
class LocalCache {
  static const _boxName = 'expense_cache';
  static const _expensesKey = 'expenses';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  Box get _box => Hive.box(_boxName);

  Future<void> saveExpenses(List<Expense> expenses) async {
    final raw = jsonEncode(expenses.map((e) => e.toJson()).toList());
    await _box.put(_expensesKey, raw);
  }

  List<Expense> readExpenses() {
    final raw = _box.get(_expensesKey);
    if (raw is! String || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Expense.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clear() => _box.delete(_expensesKey);
}
