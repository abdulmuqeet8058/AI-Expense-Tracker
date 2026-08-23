import 'chart_data.dart';
import 'expense.dart';

class BudgetProgress {
  final String category;
  final double limit;
  final double spent;

  const BudgetProgress({
    required this.category,
    required this.limit,
    required this.spent,
  });

  factory BudgetProgress.fromJson(Map<String, dynamic> json) => BudgetProgress(
        category: json['category'] as String? ?? 'Miscellaneous',
        limit: _toDouble(json['limit'] ?? json['monthly_limit']),
        spent: _toDouble(json['spent'] ?? json['current_spent']),
      );

  double get fraction => limit <= 0 ? 0 : (spent / limit);
  double get percent => fraction * 100;
}

class Dashboard {
  final double totalSpentMonth;
  final double totalIncomeMonth;
  final List<BudgetProgress> budgetProgress;
  final List<Expense> recent;
  final List<CategoryTotal> topCategories;

  const Dashboard({
    this.totalSpentMonth = 0,
    this.totalIncomeMonth = 0,
    this.budgetProgress = const [],
    this.recent = const [],
    this.topCategories = const [],
  });

  double get netMonth => totalIncomeMonth - totalSpentMonth;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        totalSpentMonth: _toDouble(json['total_spent_month']),
        totalIncomeMonth: _toDouble(json['total_income_month']),
        budgetProgress: _rows(json['budget_progress'])
            .map(BudgetProgress.fromJson)
            .toList(),
        recent: _rows(json['recent']).map(Expense.fromJson).toList(),
        topCategories:
            _rows(json['top_categories']).map(CategoryTotal.fromJson).toList(),
      );
}

List<Map<String, dynamic>> _rows(dynamic v) =>
    (v is List ? v : const []).whereType<Map<String, dynamic>>().toList();

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}
