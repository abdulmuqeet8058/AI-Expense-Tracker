class Insight {
  final String type;
  final String title;
  final String message;
  final String severity;

  const Insight({
    required this.type,
    required this.title,
    required this.message,
    this.severity = 'info',
  });

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        type: json['type'] as String? ?? 'info',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        severity: json['severity'] as String? ?? 'info',
      );
}

class SpendingForecast {
  final Map<String, double> predictions;
  final double totalPredicted;
  final int monthsAnalyzed;
  final String forecastPeriod;
  final String modelMode;
  final String currency;

  const SpendingForecast({
    required this.predictions,
    required this.totalPredicted,
    required this.monthsAnalyzed,
    required this.forecastPeriod,
    required this.modelMode,
    required this.currency,
  });

  factory SpendingForecast.fromJson(Map<String, dynamic> json) {
    final predictions = <String, double>{};
    final raw = json['predictions'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is num) predictions[key.toString()] = value.toDouble();
      });
    }
    return SpendingForecast(
      predictions: predictions,
      totalPredicted: (json['total_predicted'] as num?)?.toDouble() ?? 0,
      monthsAnalyzed: (json['months_analyzed'] as num?)?.toInt() ?? 0,
      forecastPeriod: json['forecast_period'] as String? ?? '',
      modelMode: json['model_mode'] as String? ?? 'history_fallback',
      currency: json['currency'] as String? ?? 'PKR',
    );
  }
}
