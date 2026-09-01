import 'package:flutter_test/flutter_test.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/models/insight_finding.dart';
import 'package:spendsense/services/insights/insights_rule_engine.dart';
import 'package:spendsense/models/user_goals.dart';

void main() {
  group('InsightsRuleEngine Tests', () {
    final now = DateTime.now();

    // Helper to create transactions
    MyTransaction createTx(double amount, DateTime timestamp,
        {String category = 'Food'}) {
      return MyTransaction(
        id: 'tx_${timestamp.millisecondsSinceEpoch}_${amount.toInt()}',
        amount: amount,
        timestamp: timestamp,
        merchant: 'Test Merchant',
        category: category,
        confidence: 'HIGH',
        type: 'EXPENSE',
        isConfirmed: true,
      );
    }

    // Helper to find next Saturday
    DateTime getNextSaturday(DateTime start) {
      var date = start;
      while (date.weekday != DateTime.saturday) {
        date = date.add(const Duration(days: 1));
      }
      return date;
    }

    // Helper to find next Monday
    DateTime getNextMonday(DateTime start) {
      var date = start;
      while (date.weekday != DateTime.monday) {
        date = date.add(const Duration(days: 1));
      }
      return date;
    }

    test('UT-01: evaluateWeekendSpikes - High severity (Triggered)', () {
      final saturday = getNextSaturday(now.subtract(const Duration(days: 20)));
      final sunday = saturday.add(const Duration(days: 1));
      final monday = getNextMonday(now.subtract(const Duration(days: 20)));
      final tuesday = monday.add(const Duration(days: 1));

      final transactions = [
        // Weekend: 4000
        createTx(1000, saturday),
        createTx(1000, saturday.add(const Duration(hours: 1))),
        createTx(1000, sunday),
        createTx(1000, sunday.add(const Duration(hours: 1))),
        // Weekday: 500
        createTx(250, monday),
        createTx(250, tuesday),
      ];

      final findings = InsightsRuleEngine.evaluateRules(
          transactions, UserGoals.empty(), null);

      final weekendFinding =
          findings.where((f) => f.id == 'weekend_spike').firstOrNull;
      expect(weekendFinding, isNotNull);
      expect(weekendFinding!.severity, InsightSeverity.high);
      expect(weekendFinding.trend, InsightTrend.up);
    });

    test('UT-02: evaluateWeekendSpikes - Threshold not met', () {
      final saturday = getNextSaturday(now.subtract(const Duration(days: 20)));
      final monday = getNextMonday(now.subtract(const Duration(days: 20)));

      final transactions = [
        // Weekend: 1000
        createTx(500, saturday),
        createTx(500, saturday.add(const Duration(hours: 1))),
        // Weekday: 1000
        createTx(500, monday),
        createTx(500, monday.add(const Duration(hours: 1))),
      ];

      final findings = InsightsRuleEngine.evaluateRules(
          transactions, UserGoals.empty(), null);

      final weekendFinding =
          findings.where((f) => f.id == 'weekend_spike').firstOrNull;
      expect(weekendFinding, isNull);
    });

    test('UT-03: evaluateLateNight - Triggered', () {
      final today = DateTime(now.year, now.month, now.day);
      final late1 = today
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 23, minutes: 30)); // 11:30 PM
      final late2 = today.add(const Duration(hours: 1)); // 1:00 AM
      final dayTime = today.add(const Duration(hours: 14)); // 2:00 PM

      final transactions = [
        // Late night: 3000
        createTx(1500, late1),
        createTx(1500, late2),
        // Day time: 500
        createTx(500, dayTime),
      ];

      final findings = InsightsRuleEngine.evaluateRules(
          transactions, UserGoals.empty(), null);

      final lateNightFinding =
          findings.where((f) => f.id == 'late_night').firstOrNull;
      expect(lateNightFinding, isNotNull);
      expect(lateNightFinding!.severity, InsightSeverity.medium);
    });

    test('UT-04: evaluateCategoryTrends - Triggered', () {
      final today = DateTime(now.year, now.month, now.day);
      final currentWeekDate = today.subtract(const Duration(days: 2));
      final previousWeekDate = today.subtract(const Duration(days: 10));

      final transactions = [
        // Current week Food: 2000
        createTx(2000, currentWeekDate, category: 'Food'),
        // Previous week Food: 1000
        createTx(1000, previousWeekDate, category: 'Food'),
      ];

      final findings = InsightsRuleEngine.evaluateRules(
          transactions, UserGoals.empty(), null);

      final trendFinding =
          findings.where((f) => f.id == 'cat_trend_Food').firstOrNull;
      expect(trendFinding, isNotNull);
      expect(trendFinding!.trend, InsightTrend.up);
      expect(trendFinding.emoji, '🍔');
    });

    test('UT-05: generateSavings - Triggered', () {
      final today = DateTime(now.year, now.month, now.day);
      final transactions = <MyTransaction>[];

      // Create 15 transactions in the last 30 days
      for (var i = 0; i < 15; i++) {
        transactions.add(
            createTx(300, today.subtract(Duration(days: i)), category: 'Food'));
      }

      final opportunities = InsightsRuleEngine.evaluateSavings(
          transactions, UserGoals.empty(), null);

      final deliveryOpp =
          opportunities.where((o) => o.id == 'food_delivery_freq').firstOrNull;
      expect(deliveryOpp, isNotNull);
      // (15 - 4) * 300 = 11 * 300 = 3300
      expect(deliveryOpp!.potentialAmount, '₹3300/mo');
    });

    test('UT-06: generateSavings - Healthy behavior', () {
      final today = DateTime(now.year, now.month, now.day);
      final transactions = [
        createTx(300, today.subtract(const Duration(days: 1)),
            category: 'Food'),
        createTx(300, today.subtract(const Duration(days: 10)),
            category: 'Food'),
      ];

      final opportunities = InsightsRuleEngine.evaluateSavings(
          transactions, UserGoals.empty(), null);

      expect(opportunities, isEmpty);
    });

    test('UT-07: Empty Findings', () {
      final findings =
          InsightsRuleEngine.evaluateRules([], UserGoals.empty(), null);
      final opportunities =
          InsightsRuleEngine.evaluateSavings([], UserGoals.empty(), null);

      expect(findings, isEmpty);
      expect(opportunities, isEmpty);
    });
  });
}
