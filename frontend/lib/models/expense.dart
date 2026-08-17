class Location {
  final double lat;
  final double lng;
  final String? address;

  const Location({required this.lat, required this.lng, this.address});

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        lat: _toDouble(json['lat']),
        lng: _toDouble(json['lng']),
        address: json['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (address != null) 'address': address,
      };
}

class Expense {
  final String id;
  final String userId;
  final double amount;
  final String description;
  final String? category;
  final String? subCategory;
  final DateTime date;
  final String paymentMethod;
  final Location? location;
  final String? receiptUrl;
  final bool isIncome;
  final double? confidenceScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.description,
    this.category,
    this.subCategory,
    required this.date,
    this.paymentMethod = 'cash',
    this.location,
    this.receiptUrl,
    this.isIncome = false,
    this.confidenceScore,
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      description: json['description'] as String? ?? '',
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      date: _toDate(json['date']) ?? DateTime.now(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      location: json['location'] is Map<String, dynamic>
          ? Location.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      receiptUrl: json['receipt_url'] as String?,
      isIncome: json['is_income'] as bool? ?? false,
      confidenceScore:
          json['confidence_score'] == null ? null : _toDouble(json['confidence_score']),
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'description': description,
        'category': category,
        'sub_category': subCategory,
        'date': date.toUtc().toIso8601String(),
        'payment_method': paymentMethod,
        'location': location?.toJson(),
        'receipt_url': receiptUrl,
        'is_income': isIncome,
        'confidence_score': confidenceScore,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  Expense copyWith({
    double? amount,
    String? description,
    String? category,
    String? subCategory,
    DateTime? date,
    String? paymentMethod,
    Location? location,
    String? receiptUrl,
    bool? isIncome,
    double? confidenceScore,
  }) {
    return Expense(
      id: id,
      userId: userId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      location: location ?? this.location,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      isIncome: isIncome ?? this.isIncome,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get hasLocation => location != null;
  double get signedAmount => isIncome ? amount : -amount;
}

/// Result of a /ml/categorize call. Lives here since it's category-shaped and
/// the add-expense screen already imports this file for [Expense].
class CategorySuggestion {
  final String category;
  final double confidence;

  const CategorySuggestion({required this.category, required this.confidence});

  factory CategorySuggestion.fromJson(Map<String, dynamic> json) =>
      CategorySuggestion(
        category: json['category'] as String? ?? 'Miscellaneous',
        confidence: _toDouble(json['confidence']),
      );
}

class CategorizeResult {
  final String category;
  final double confidence;
  final List<CategorySuggestion> alternatives;

  const CategorizeResult({
    required this.category,
    required this.confidence,
    this.alternatives = const [],
  });

  factory CategorizeResult.fromJson(Map<String, dynamic> json) {
    final alts = (json['alternatives'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CategorySuggestion.fromJson)
        .toList();
    return CategorizeResult(
      category: json['category'] as String? ?? 'Miscellaneous',
      confidence: _toDouble(json['confidence']),
      alternatives: alts,
    );
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
