import 'package:flutter/material.dart';
import '../theme.dart';

// Icon + color per canonical category. Keep the strings in sync with the
// backend's 13-category list. Unknown categories fall through to Misc.
IconData iconForCategory(String category) {
  switch (category) {
    case 'Food & Dining':
      return Icons.restaurant;
    case 'Transportation':
      return Icons.directions_car;
    case 'Shopping':
      return Icons.shopping_bag;
    case 'Entertainment':
      return Icons.movie;
    case 'Bills & Utilities':
      return Icons.receipt_long;
    case 'Healthcare':
      return Icons.local_hospital;
    case 'Education':
      return Icons.school;
    case 'Groceries':
      return Icons.local_grocery_store;
    case 'Travel':
      return Icons.flight;
    case 'Rent':
      return Icons.home;
    case 'Insurance':
      return Icons.verified_user;
    case 'Personal Care':
      return Icons.spa;
    default:
      return Icons.category;
  }
}

Color colorForCategory(String category) {
  switch (category) {
    case 'Food & Dining':
      return AppColors.secondary;
    case 'Transportation':
      return AppColors.accent;
    case 'Shopping':
      return const Color(0xFFEC407A);
    case 'Entertainment':
      return const Color(0xFF7C4DFF);
    case 'Bills & Utilities':
      return const Color(0xFF00ACC1);
    case 'Healthcare':
      return const Color(0xFFE53935);
    case 'Education':
      return const Color(0xFF3949AB);
    case 'Groceries':
      return AppColors.primary;
    case 'Travel':
      return const Color(0xFF00BFA5);
    case 'Rent':
      return const Color(0xFF8D6E63);
    case 'Insurance':
      return const Color(0xFF546E7A);
    case 'Personal Care':
      return const Color(0xFFD81B60);
    default:
      return const Color(0xFF9E9E9E);
  }
}

/// Pill for a single category. Doubles as a filter toggle when [selected]
/// is driven by the parent.
class CategoryChip extends StatelessWidget {
  final String category;
  final bool selected;
  final VoidCallback? onTap;
  final bool showIcon;

  const CategoryChip({
    super.key,
    required this.category,
    this.selected = false,
    this.onTap,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = colorForCategory(category);
    final bg = selected ? c : c.withValues(alpha:0.12);
    final fg = selected ? Colors.white : c;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: c.withValues(alpha:0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(iconForCategory(category), size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
