/// SpendSense - Recent transactions and summary service.

import '../core/constants.dart';
import '../models/transaction.dart';
import '../services/local_storage_service.dart';

class RecentTransactionsService {
  RecentTransactionsService._();
  static final RecentTransactionsService instance =
      RecentTransactionsService._();

  Future<List<MyTransaction>> fetchRecent({int limit = 30}) async {
    final transactions =
        await LocalStorageService.instance.getRecentConfirmed(limit: limit);
    return transactions
        .where((tx) => tx.category != AppConstants.categoryIgnored)
        .toList();
  }

  Future<List<AggregatedTransaction>> fetchAggregatedRecent() async {
    final transactions = await fetchRecent(limit: 100);
    final groups = <String, double>{};
    final latestTimestamps = <String, DateTime>{};

    for (final tx in transactions) {
      if (tx.category == AppConstants.categoryIgnored) continue;
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
      where:
          'is_confirmed = 1 AND timestamp >= ? AND type = ? AND category != ?',
      whereArgs: [
        start,
        AppConstants.typeExpense,
        AppConstants.categoryIgnored
      ],
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

  Future<List<double>> fetchTrendData() async {
    final db = await LocalStorageService.instance.database;
    final now = DateTime.now();
    // Fetch last 7 days of spending
    final sevenDaysAgo =
        now.subtract(const Duration(days: 6)).millisecondsSinceEpoch;

    final results = await db.query(
      AppConstants.transactionsTable,
      where:
          'is_confirmed = 1 AND timestamp >= ? AND type = ? AND category != ?',
      whereArgs: [
        sevenDaysAgo,
        AppConstants.typeExpense,
        AppConstants.categoryIgnored
      ],
      orderBy: 'timestamp ASC',
    );

    final dailySpending = <int, double>{};
    for (var i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final dayKey =
          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      dailySpending[dayKey] = 0;
    }

    for (final row in results) {
      final timestamp = row['timestamp'] as int;
      final amount = (row['amount'] as num).toDouble();
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final dayKey = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      if (dailySpending.containsKey(dayKey)) {
        dailySpending[dayKey] = dailySpending[dayKey]! + amount;
      }
    }

    // Sort keys and return values
    final sortedKeys = dailySpending.keys.toList()..sort();
    return sortedKeys.map((key) => dailySpending[key]!).toList();
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
