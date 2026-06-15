import 'package:flutter_test/flutter_test.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/services/insights/insights_metrics_engine.dart';

void main() {
  group('InsightsMetricsEngine Tests', () {
    final now = DateTime.now();

    // Helper to create transactions
    MyTransaction createTx(double amount, DateTime timestamp, String category) {
      return MyTransaction(
        id: 'tx_${timestamp.millisecondsSinceEpoch}',
        amount: amount,
        timestamp: timestamp,
        merchant: 'Test Merchant',
        category: category,
        confidence: 'HIGH',
        type: 'EXPENSE',
        isConfirmed: true,
      );
    }

    test('computeWeeklySpending aggregates data correctly for the last 7 days',
        () {
      final transactions = [
        createTx(100, now, 'Food'), // Today
        createTx(
            200, now.subtract(const Duration(days: 1)), 'Food'), // Yesterday
        createTx(50, now.subtract(const Duration(days: 1)),
            'Transport'), // Yesterday (different category)
        createTx(300, now.subtract(const Duration(days: 6)),
            'Shopping'), // 6 days ago
        createTx(
            500, now.subtract(const Duration(days: 8)), 'Rent'), // Out of range
      ];

      final result = InsightsMetricsEngine.computeWeeklySpending(transactions);

      expect(result.length, 7);
      expect(result.last.amount, 100); // Today
      expect(result[result.length - 2].amount, 250); // Yesterday (200 + 50)
      expect(result.first.amount, 300); // 6 days ago
    });

    test('computeTopCategories returns correctly sorted and capped categories',
        () {
      final transactions = [
        createTx(1000, now, 'Rent'),
        createTx(500, now, 'Food'),
        createTx(200, now, 'Food'),
        createTx(300, now, 'Transport'),
        createTx(100, now, 'Health'),
        createTx(50, now, 'Fun'),
        createTx(10, now, 'Others'),
      ];

      final result = InsightsMetricsEngine.computeTopCategories(transactions);

      expect(result.length, 5); // Capped at 5
      expect(result[0].name, 'Rent');
      expect(result[0].amount, 1000);
      expect(result[1].name, 'Food');
      expect(result[1].amount, 700);
    });

    test('computeWeeklyImprovement calculates percentage correctly', () {
      final transactions = [
        // Current week (last 7 days): Total 700
        createTx(400, now.subtract(const Duration(days: 1)), 'Food'),
        createTx(300, now.subtract(const Duration(days: 2)), 'Food'),
        // Previous week (days 8-14): Total 1000
        createTx(1000, now.subtract(const Duration(days: 10)), 'Rent'),
      ];

      final improvement =
          InsightsMetricsEngine.computeWeeklyImprovement(transactions);

      // (1000 - 700) / 1000 * 100 = 30%
      expect(improvement, closeTo(30.0, 0.1));
    });

    test('computeMonthTrend calculates percentage correctly', () {
      final transactions = [
        // Current month (last 30 days): Total 2000
        createTx(2000, now.subtract(const Duration(days: 5)), 'Rent'),
        // Previous month (days 31-60): Total 1000
        createTx(1000, now.subtract(const Duration(days: 40)), 'Rent'),
      ];

      final trend = InsightsMetricsEngine.computeMonthTrend(transactions);

      // (2000 - 1000) / 1000 * 100 = 100% increase
      expect(trend, closeTo(100.0, 0.1));
    });

    test('computeMonthlyTrend groups data into 4 weekly buckets', () {
      final transactions = [
        createTx(100, now.subtract(const Duration(days: 1)),
            'Food'), // Week 4 (Latest)
        createTx(200, now.subtract(const Duration(days: 8)), 'Food'), // Week 3
        createTx(300, now.subtract(const Duration(days: 15)), 'Food'), // Week 2
        createTx(400, now.subtract(const Duration(days: 22)), 'Food'), // Week 1
      ];

      final result = InsightsMetricsEngine.computeMonthlyTrend(transactions);

      expect(result.length, 4);
      expect(result[3].amount, 100); // Week 4
      expect(result[2].amount, 200); // Week 3
      expect(result[1].amount, 300); // Week 2
      expect(result[0].amount, 400); // Week 1
    });
  });
}
