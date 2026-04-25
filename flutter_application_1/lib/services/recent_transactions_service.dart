/// SpendSense - Recent transactions and summary service.

import '../core/constants.dart';
import '../models/transaction.dart';
import '../services/local_storage_service.dart';

class RecentTransactionsService {
  RecentTransactionsService._();
  static final RecentTransactionsService instance =
      RecentTransactionsService._();

  Future<List<MyTransaction>> fetchRecent({int limit = 30}) async {
    return LocalStorageService.instance.getRecentConfirmed(limit: limit);
  }

  Future<List<AggregatedTransaction>> fetchAggregatedRecent() async {
    final transactions = await fetchRecent(limit: 100);
    final groups = <String, double>{};
    final latestTimestamps = <String, DateTime>{};

    for (final tx in transactions) {
      groups[tx.category] = (groups[tx.category] ?? 0) + tx.amount;
      final currentLatest = latestTimestamps[tx.category];
      if (currentLatest == null || tx.timestamp.isAfter(currentLatest)) {
        latestTimestamps[tx.category] = tx.timestamp;
      }
    }

    final result = groups.entries.map((e) {
      return AggregatedTransaction(
        category: e.key,
        totalAmount: e.value,
        lastTransactionAt: latestTimestamps[e.key]!,
      );
    }).toList();

    // Sort by latest transaction time
    result.sort((a, b) => b.lastTransactionAt.compareTo(a.lastTransactionAt));
    return result;
  }

  Future<MonthlySummary> fetchMonthlySummary() async {
    final db = await LocalStorageService.instance.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'is_confirmed = 1 AND timestamp >= ? AND type = ?',
      whereArgs: [start, AppConstants.typeExpense],
    );

    double total = 0;
    final byCategory = <String, double>{};

    for (final row in results) {
      final amount = (row['amount'] as num).toDouble();
      final category = row['category'] as String;
      total += amount;
      byCategory[category] = (byCategory[category] ?? 0) + amount;
    }

    return MonthlySummary(
      totalSpent: total,
      byCategory: byCategory,
      txCount: results.length,
      month: now,
    );
  }
}

class MonthlySummary {
  final double totalSpent;
  final Map<String, double> byCategory;
  final int txCount;
  final DateTime month;

  const MonthlySummary({
    required this.totalSpent,
    required this.byCategory,
    required this.txCount,
    required this.month,
  });

  String get topCategory {
    if (byCategory.isEmpty) return '-';
    return byCategory.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String get formattedTotal => '₹${totalSpent.toStringAsFixed(0)}';
}

class AggregatedTransaction {
  final String category;
  final double totalAmount;
  final DateTime lastTransactionAt;

  AggregatedTransaction({
    required this.category,
    required this.totalAmount,
    required this.lastTransactionAt,
  });
}
