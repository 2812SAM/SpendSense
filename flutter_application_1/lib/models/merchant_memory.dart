/// SpendSense — MerchantMemory Model
/// This is the "personal dictionary" — the core learning mechanism.
/// Once a user confirms a merchant's category, it's saved here forever.
/// Next time the same merchant appears, category is auto-applied.
///
/// Stored in SQLite locally on device.

class MerchantMemory {
  final int? id; // SQLite auto-increment primary key
  final String merchantKey; // normalised merchant name (lowercase, trimmed)
  final String category; // user-confirmed category
  final String type; // EXPENSE or LOAN
  final bool isDynamic; // If true, always ask for confirmation
  final int count; // how many times this merchant has been seen
  final DateTime lastSeen; // last transaction date

  const MerchantMemory({
    this.id,
    required this.merchantKey,
    required this.category,
    required this.type,
    this.isDynamic = false,
    this.count = 1,
    required this.lastSeen,
  });

  // ── SQLite serialization ──────────────────────────────────────────────────
  factory MerchantMemory.fromMap(Map<String, dynamic> map) {
    return MerchantMemory(
      id: map['id'] as int?,
      merchantKey: map['merchant_key'] as String,
      category: map['category'] as String,
      type: map['type'] as String,
      isDynamic: (map['is_dynamic'] as int? ?? 0) == 1,
      count: map['count'] as int,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'merchant_key': merchantKey,
      'category': category,
      'type': type,
      'is_dynamic': isDynamic ? 1 : 0,
      'count': count,
      'last_seen': lastSeen.millisecondsSinceEpoch,
    };
  }

  MerchantMemory copyWith({
    String? category,
    String? type,
    bool? isDynamic,
    int? count,
    DateTime? lastSeen,
  }) {
    return MerchantMemory(
      id: id,
      merchantKey: merchantKey,
      category: category ?? this.category,
      type: type ?? this.type,
      isDynamic: isDynamic ?? this.isDynamic,
      count: count ?? this.count,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Normalise merchant name for consistent dictionary lookups.
  /// "ZOMATO ONLINE" and "Zomato" both become "zomato".
  static String normalise(String raw) =>
      raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  String toString() =>
      'MerchantMemory($merchantKey → $category [$count times], dynamic: $isDynamic)';
}
