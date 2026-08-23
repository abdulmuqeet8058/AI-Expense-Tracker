class CategoryTotal {
  final String category;
  final double total;

  const CategoryTotal({required this.category, required this.total});

  factory CategoryTotal.fromJson(Map<String, dynamic> json) => CategoryTotal(
        category: json['category'] as String? ?? 'Miscellaneous',
        total: _toDouble(json['total'] ?? json['amount']),
      );
}

class DailyTotal {
  final String date;
  final double total;

  const DailyTotal({required this.date, required this.total});

  factory DailyTotal.fromJson(Map<String, dynamic> json) => DailyTotal(
        date: (json['date'] ?? '').toString(),
        total: _toDouble(json['total'] ?? json['amount']),
      );

  DateTime? get dateTime => DateTime.tryParse(date);
}

class MonthlyTotal {
  final String month;
  final double total;

  const MonthlyTotal({required this.month, required this.total});

  factory MonthlyTotal.fromJson(Map<String, dynamic> json) => MonthlyTotal(
        month: (json['month'] ?? '').toString(),
        total: _toDouble(json['total'] ?? json['amount']),
      );
}

class ChartData {
  final List<CategoryTotal> byCategory;
  final List<DailyTotal> daily;
  final List<MonthlyTotal> monthly;

  const ChartData({
    this.byCategory = const [],
    this.daily = const [],
    this.monthly = const [],
  });

  factory ChartData.fromJson(Map<String, dynamic> json) => ChartData(
        byCategory:
            _rows(json['by_category']).map(CategoryTotal.fromJson).toList(),
        daily: _rows(json['daily']).map(DailyTotal.fromJson).toList(),
        monthly: _rows(json['monthly']).map(MonthlyTotal.fromJson).toList(),
      );
}

List<Map<String, dynamic>> _rows(dynamic v) =>
    (v is List ? v : const []).whereType<Map<String, dynamic>>().toList();

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}
