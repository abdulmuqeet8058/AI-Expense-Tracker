import 'package:flutter/material.dart';

import '../models/insight.dart';
import '../theme.dart';

class InsightBanner extends StatelessWidget {
  const InsightBanner({super.key, required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _color => switch (insight.severity.toLowerCase()) {
        'critical' || 'danger' || 'error' => AppColors.danger,
        'warning' || 'alert' => AppColors.warning,
        'success' => AppColors.success,
        _ => AppColors.accent,
      };

  IconData get _icon => switch (insight.type.toLowerCase()) {
        'anomaly' => Icons.warning_amber_rounded,
        'forecast' || 'prediction' => Icons.trending_up_rounded,
        'budget' => Icons.account_balance_wallet_outlined,
        'savings' => Icons.savings_outlined,
        'trend' => Icons.show_chart_rounded,
        'spending' => Icons.pie_chart_outline_rounded,
        _ => Icons.auto_awesome_rounded,
      };
}
