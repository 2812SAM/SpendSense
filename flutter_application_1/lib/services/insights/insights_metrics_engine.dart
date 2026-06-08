import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/insights_snapshot.dart';
import '../../models/transaction.dart';

class InsightsMetricsEngine {
  /// Computes weekly spending for the last 7 days (including today).
  static List<SpendingDatum> computeWeeklySpending(
      List<MyTransaction> transactions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weeklySpending = <SpendingDatum>[];

    for (var i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayLabel = _getDayLabel(date);
      final dayAmount = transactions
          .where((tx) =>
              tx.timestamp.year == date.year &&
              tx.timestamp.month == date.month &&
              tx.timestamp.day == date.day)
          .fold(0.0, (sum, tx) => sum + tx.amount);

      weeklySpending.add(SpendingDatum(label: dayLabel, amount: dayAmount));
    }

    return weeklySpending;
  }

  /// Computes monthly trend (last 4 weeks).
  static List<SpendingDatum> computeMonthlyTrend(
      List<MyTransaction> transactions) {
    final now = DateTime.now();
    final monthlyTrend = <SpendingDatum>[];

    for (var i = 3; i >= 0; i--) {
      final weekEnd = now.subtract(Duration(days: i * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 7));

      final weekAmount = transactions
          .where((tx) =>
              tx.timestamp.isAfter(weekStart) &&
              tx.timestamp.isBefore(weekEnd.add(const Duration(seconds: 1))))
          .fold(0.0, (sum, tx) => sum + tx.amount);

      monthlyTrend
          .add(SpendingDatum(label: 'Week ${4 - i}', amount: weekAmount));
    }

    return monthlyTrend;
  }

  /// Computes top categories and their trends.
  static List<CategoryInsight> computeTopCategories(
      List<MyTransaction> transactions) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sixtyDaysAgo = now.subtract(const Duration(days: 60));

    final currentMonthTx = transactions
        .where((tx) => tx.timestamp.isAfter(thirtyDaysAgo))
        .toList();
    final previousMonthTx = transactions
        .where((tx) =>
            tx.timestamp.isAfter(sixtyDaysAgo) &&
            tx.timestamp.isBefore(thirtyDaysAgo))
        .toList();

    final categoryTotals = <String, double>{};
    for (final tx in currentMonthTx) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final insights = <CategoryInsight>[];
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.cyan,
      Colors.orange,
      Colors.purple,
      Colors.green,
      Colors.amber,
      Colors.indigo,
    ];

    for (var i = 0; i < min(sortedCategories.length, 5); i++) {
      final category = sortedCategories[i].key;
      final amount = sortedCategories[i].value;

      final previousAmount = previousMonthTx
          .where((tx) => tx.category == category)
          .fold(0.0, (sum, tx) => sum + tx.amount);

      double trend = 0;
      if (previousAmount > 0) {
        trend = ((amount - previousAmount) / previousAmount) * 100;
      }

      insights.add(CategoryInsight(
        name: category,
        amount: amount,
        trend: trend,
        color: colors[i % colors.length],
      ));
    }

    return insights;
  }

  /// Computes weekly improvement percentage (last 7 days vs previous 7 days).
  static double computeWeeklyImprovement(List<MyTransaction> transactions) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
    final fourteenDaysAgo = todayStart.subtract(const Duration(days: 14));

    final currentWeekAmount = transactions
        .where((tx) =>
            tx.timestamp.isAfter(sevenDaysAgo) ||
            tx.timestamp.isAtSameMomentAs(sevenDaysAgo))
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final previousWeekAmount = transactions
        .where((tx) =>
            tx.timestamp.isAfter(fourteenDaysAgo) &&
            tx.timestamp.isBefore(sevenDaysAgo))
        .fold(0.0, (sum, tx) => sum + tx.amount);

    if (previousWeekAmount == 0) return 0;
    return ((previousWeekAmount - currentWeekAmount) / previousWeekAmount) *
        100;
  }

  /// Computes monthly trend percentage (last 30 days vs previous 30 days).
  static double computeMonthTrend(List<MyTransaction> transactions) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
    final sixtyDaysAgo = todayStart.subtract(const Duration(days: 60));

    final currentMonthAmount = transactions
        .where((tx) =>
            tx.timestamp.isAfter(thirtyDaysAgo) ||
            tx.timestamp.isAtSameMomentAs(thirtyDaysAgo))
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final previousMonthAmount = transactions
        .where((tx) =>
            tx.timestamp.isAfter(sixtyDaysAgo) &&
            tx.timestamp.isBefore(thirtyDaysAgo))
        .fold(0.0, (sum, tx) => sum + tx.amount);

    if (previousMonthAmount == 0) return 0;
    return ((currentMonthAmount - previousMonthAmount) / previousMonthAmount) *
        100;
  }

  static String _getDayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}
