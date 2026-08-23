import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

const _overBudget = Color(0xFFE53935);

// green -> orange -> red depending on how full the budget is
Color _budgetColor(double fraction, double alertFraction) {
  if (fraction >= 1.0) return _overBudget;
  if (fraction >= alertFraction) return AppColors.secondary;
  return AppColors.primary;
}

/// Animated horizontal budget bar. Pass raw [spent]/[limit]; it fills and
/// recolors itself and animates whenever the values change.
class BudgetProgress extends StatelessWidget {
  final String label;
  final double spent;
  final double limit;
  final double alertThreshold; // percent, e.g. 80
  final String currencySymbol;
  final bool animate;

  const BudgetProgress({
    super.key,
    required this.label,
    required this.spent,
    required this.limit,
    this.alertThreshold = 80,
    this.currencySymbol = 'Rs',
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fraction = limit <= 0 ? 0.0 : spent / limit;
    final alertFraction = alertThreshold / 100;
    final barColor = _budgetColor(fraction, alertFraction);
    final track = cs.onSurface.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$currencySymbol ${_fmt(spent)} / ${_fmt(limit)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                  duration: Duration(milliseconds: animate ? 700 : 0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Stack(
                      children: [
                        Container(width: maxW, height: 10, color: track),
                        Container(
                          width: maxW * value,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                barColor.withValues(alpha: 0.75),
                                barColor
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(fraction * 100).toStringAsFixed(0)}% used',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (fraction >= 1.0)
              Text('Over budget',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: _overBudget, fontWeight: FontWeight.w600))
            else if (fraction >= alertFraction)
              Text('Near limit',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

/// Circular budget gauge for tighter spaces (dashboard tiles). Sweeps from 0
/// to the current fraction on build.
class BudgetRing extends StatelessWidget {
  final double spent;
  final double limit;
  final double size;
  final double stroke;
  final double alertThreshold;
  final String? centerLabel;
  final bool animate;

  const BudgetRing({
    super.key,
    required this.spent,
    required this.limit,
    this.size = 96,
    this.stroke = 10,
    this.alertThreshold = 80,
    this.centerLabel,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fraction = limit <= 0 ? 0.0 : spent / limit;
    final color = _budgetColor(fraction, alertThreshold / 100);
    final track = cs.onSurface.withValues(alpha: 0.08);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        duration: Duration(milliseconds: animate ? 800 : 0),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  fraction: value,
                  color: color,
                  track: track,
                  stroke: stroke,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(fraction * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, color: color),
                  ),
                  if (centerLabel != null)
                    Text(
                      centerLabel!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;

    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

// light thousands separator so widgets don't need to pull in intl
String _fmt(double v) {
  final neg = v < 0;
  final s = v.abs().toStringAsFixed(0);
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return neg ? '-$b' : b.toString();
}
