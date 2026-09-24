class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.merchant,
    required this.category,
    required this.cadence,
    required this.occurrenceCount,
    required this.expectedAmount,
    required this.monthlyEquivalent,
    required this.nextExpectedDate,
    required this.daysUntilDue,
    required this.confidence,
    required this.status,
    this.priceChangePercent,
  });

  final String id;
  final String merchant;
  final String category;
  final String cadence;
  final int occurrenceCount;
  final double expectedAmount;
  final double monthlyEquivalent;
  final DateTime nextExpectedDate;
  final int daysUntilDue;
  final double confidence;
  final String status;
  final double? priceChangePercent;

  factory RecurringPayment.fromJson(Map<String, dynamic> json) {
    return RecurringPayment(
      id: json['id'] as String? ?? '',
      merchant: json['merchant'] as String? ?? 'Recurring payment',
      category: json['category'] as String? ?? 'Miscellaneous',
      cadence: json['cadence'] as String? ?? 'Recurring',
      occurrenceCount: (json['occurrence_count'] as num?)?.toInt() ?? 0,
      expectedAmount: (json['expected_amount'] as num?)?.toDouble() ?? 0,
      monthlyEquivalent: (json['monthly_equivalent'] as num?)?.toDouble() ?? 0,
      nextExpectedDate: DateTime.tryParse(
            json['next_expected_date'] as String? ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      daysUntilDue: (json['days_until_due'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'scheduled',
      priceChangePercent: (json['price_change_percent'] as num?)?.toDouble(),
    );
  }
}

class RecurringSummary {
  const RecurringSummary({
    required this.detectedCount,
    required this.monthlyCommitment,
    required this.upcoming30Days,
    required this.priceIncreases,
    required this.currency,
  });

  final int detectedCount;
  final double monthlyCommitment;
  final int upcoming30Days;
  final int priceIncreases;
  final String currency;

  factory RecurringSummary.fromJson(Map<String, dynamic> json) {
    return RecurringSummary(
      detectedCount: (json['detected_count'] as num?)?.toInt() ?? 0,
      monthlyCommitment: (json['monthly_commitment'] as num?)?.toDouble() ?? 0,
      upcoming30Days: (json['upcoming_30_days'] as num?)?.toInt() ?? 0,
      priceIncreases: (json['price_increases'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'PKR',
    );
  }
}

class RecurringPaymentsResult {
  const RecurringPaymentsResult({
    required this.payments,
    required this.summary,
  });

  final List<RecurringPayment> payments;
  final RecurringSummary summary;

  factory RecurringPaymentsResult.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['recurring_payments'];
    final rawSummary = json['summary'];
    return RecurringPaymentsResult(
      payments: rawPayments is List
          ? rawPayments
              .whereType<Map<String, dynamic>>()
              .map(RecurringPayment.fromJson)
              .toList()
          : const [],
      summary: RecurringSummary.fromJson(
        rawSummary is Map<String, dynamic> ? rawSummary : const {},
      ),
    );
  }
}
