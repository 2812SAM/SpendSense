/// SpendSense - Transaction model.

import '../core/constants.dart';

class MyTransaction {
  final String id;
  final DateTime timestamp;
  final double amount;
  final String merchant;
  final String category;
  final String confidence;
  final String type;
  final String note;
  final String rawSms;
  final bool isLogged;
  final bool isConfirmed;
  final String syncStatus;

  const MyTransaction({
    required this.id,
    required this.timestamp,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.confidence,
    required this.type,
    this.note = '',
    this.rawSms = '',
    this.isLogged = false,
    this.isConfirmed = false,
    this.syncStatus = AppConstants.syncPending,
  });

  factory MyTransaction.fromClaudeResponse(
    Map<String, dynamic> json,
    String rawSms,
  ) {
    final merchant = (json['merchant'] as String?)?.trim();
    final category = (json['category'] as String?)?.trim();
    final confidence = (json['confidence'] as String?)?.trim();
    final type = (json['type'] as String?)?.trim();

    return MyTransaction(
      id: _generateId(),
      timestamp: DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      merchant: merchant?.isNotEmpty == true ? merchant! : 'Unknown',
      category: category?.isNotEmpty == true ? category! : 'ASK_USER',
      confidence: confidence?.isNotEmpty == true
          ? confidence!
          : AppConstants.confidenceLow,
      type: type?.isNotEmpty == true ? type! : AppConstants.typeExpense,
      note: (json['note'] as String?)?.trim() ?? '',
      rawSms: rawSms,
    );
  }

  factory MyTransaction.manualReview({
    required String rawSms,
    required String merchant,
    required double amount,
    String note = 'Needs manual review',
  }) {
    return MyTransaction(
      id: _generateId(),
      timestamp: DateTime.now(),
      amount: amount,
      merchant: merchant,
      category: 'ASK_USER',
      confidence: AppConstants.confidenceLow,
      type: AppConstants.typeExpense,
      note: note,
      rawSms: rawSms,
    );
  }

  MyTransaction copyWith({
    DateTime? timestamp,
    double? amount,
    String? merchant,
    String? category,
    String? confidence,
    String? type,
    String? note,
    String? rawSms,
    bool? isLogged,
    bool? isConfirmed,
    String? syncStatus,
  }) {
    return MyTransaction(
      id: id,
      timestamp: timestamp ?? this.timestamp,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      type: type ?? this.type,
      note: note ?? this.note,
      rawSms: rawSms ?? this.rawSms,
      isLogged: isLogged ?? this.isLogged,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'confidence': confidence,
      'type': type,
      'note': note,
      'raw_sms': rawSms,
      'is_logged': isLogged ? 1 : 0,
      'is_confirmed': isConfirmed ? 1 : 0,
      'sync_status': syncStatus,
    };
  }

  factory MyTransaction.fromMap(Map<String, dynamic> map) {
    return MyTransaction(
      id: map['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      confidence: map['confidence'] as String,
      type: map['type'] as String,
      note: map['note'] as String,
      rawSms: map['raw_sms'] as String,
      isLogged: (map['is_logged'] as int) == 1,
      isConfirmed: (map['is_confirmed'] as int) == 1,
      syncStatus: map['sync_status'] as String? ?? AppConstants.syncPending,
    );
  }

  Map<String, dynamic> toSheetJson() {
    return {
      'date': _formatDate(timestamp),
      'time': _formatTime(timestamp),
      'amount': amount.toStringAsFixed(2),
      'merchant': merchant,
      'category': category,
      'note': note,
      'confidence': confidence,
      'type': type,
    };
  }

  bool get requiresUserInput =>
      category == 'ASK_USER' || confidence == AppConstants.confidenceLow;

  bool get isLoan => type == AppConstants.typeLoan;

  static String _generateId() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 1000}';
  }

  static String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day'; // Standard ISO format for Sheets
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  String toString() {
    return 'Transaction(₹$amount | $merchant | $category | $confidence | $type)';
  }
}
