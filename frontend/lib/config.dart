import 'package:flutter/material.dart';

/// Backend base URL.
///
/// 10.0.2.2 is the Android emulator's alias for the host machine. On the iOS
/// simulator use http://localhost:8000/api, and on a physical device swap in
/// your machine's LAN IP (e.g. http://192.168.1.20:8000/api).
///
/// Overridable at build or run time:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.100.5:8000/api',
);

/// The canonical 13 categories. MUST stay byte-for-byte identical to the
/// backend list, otherwise categorization + filtering break.
const List<String> kCategories = [
  'Food & Dining',
  'Transportation',
  'Shopping',
  'Entertainment',
  'Bills & Utilities',
  'Healthcare',
  'Education',
  'Groceries',
  'Travel',
  'Rent',
  'Insurance',
  'Personal Care',
  'Miscellaneous',
];

const List<String> kPaymentMethods = [
  'cash',
  'card',
  'bank',
  'wallet',
  'other',
];

const String kDefaultCurrency = 'PKR';
const String kDefaultCurrencySymbol = 'Rs';

// Per-category color/icon so charts, chips and lists stay visually consistent
// across screens. Anything not in the map falls back to a neutral grey.
const Map<String, Color> kCategoryColors = {
  'Food & Dining': Color(0xFFFF7043),
  'Transportation': Color(0xFF42A5F5),
  'Shopping': Color(0xFFEC407A),
  'Entertainment': Color(0xFF7C4DFF),
  'Bills & Utilities': Color(0xFF00ACC1),
  'Healthcare': Color(0xFFE53935),
  'Education': Color(0xFF3949AB),
  'Groceries': Color(0xFF66BB6A),
  'Travel': Color(0xFF00BFA5),
  'Rent': Color(0xFF8D6E63),
  'Insurance': Color(0xFF546E7A),
  'Personal Care': Color(0xFFD81B60),
  'Miscellaneous': Color(0xFF9E9E9E),
};

const Map<String, IconData> kCategoryIcons = {
  'Food & Dining': Icons.restaurant,
  'Transportation': Icons.directions_car,
  'Shopping': Icons.shopping_bag,
  'Entertainment': Icons.movie,
  'Bills & Utilities': Icons.receipt_long,
  'Healthcare': Icons.local_hospital,
  'Education': Icons.school,
  'Groceries': Icons.local_grocery_store,
  'Travel': Icons.flight,
  'Rent': Icons.home,
  'Insurance': Icons.verified_user,
  'Personal Care': Icons.spa,
  'Miscellaneous': Icons.category,
};

Color categoryColor(String? category) =>
    kCategoryColors[category] ?? const Color(0xFF9E9E9E);

IconData categoryIcon(String? category) =>
    kCategoryIcons[category] ?? Icons.category;
