class User {
  final String id;
  final String email;
  final String fullName;
  final String currency;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.currency = 'PKR',
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: json['email'] as String? ?? '',
      fullName:
          json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      currency: json['currency'] as String? ?? 'PKR',
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'currency': currency,
        'created_at': createdAt?.toUtc().toIso8601String(),
      };

  User copyWith({String? fullName, String? currency}) => User(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        currency: currency ?? this.currency,
        createdAt: createdAt,
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
