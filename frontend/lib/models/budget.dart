class Budget {
  final String id;
  final String userId;
  final String category;
  final double monthlyLimit;
  final int month;
  final int year;
  final double alertThreshold;
  final double currentSpent;
  final DateTime? createdAt;

  const Budget({
    required this.id,
    required this.userId,
    required this.category,
    required this.monthlyLimit,
    required this.month,
    required this.year,
    this.alertThreshold = 80,
    this.currentSpent = 0,
    this.createdAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      category: json['category'] as String? ?? 'Miscellaneous',
      monthlyLimit: _toDouble(json['monthly_limit']),
      month: _toInt(json['month']),
      year: _toInt(json['year']),
      alertThreshold: json['alert_threshold'] == null
          ? 80
          : _toDouble(json['alert_threshold']),
      currentSpent: _toDouble(json['current_spent']),
      createdAt: _toDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'category': category,
        'monthly_limit': monthlyLimit,
        'month': month,
        'year': year,
        'alert_threshold': alertThreshold,
        'current_spent': currentSpent,
        'created_at': createdAt?.toUtc().toIso8601String(),
      };

  double get remaining => monthlyLimit - currentSpent;
  double get fraction => monthlyLimit <= 0 ? 0 : (currentSpent / monthlyLimit);
  double get spentPercent => fraction * 100;
  bool get isOverBudget => currentSpent > monthlyLimit;
  bool get isNearLimit => spentPercent >= alertThreshold;

  Budget copyWith({
    String? category,
    double? monthlyLimit,
    int? month,
    int? year,
    double? alertThreshold,
    double? currentSpent,
  }) {
    return Budget(
      id: id,
      userId: userId,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      month: month ?? this.month,
      year: year ?? this.year,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      currentSpent: currentSpent ?? this.currentSpent,
      createdAt: createdAt,
    );
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
