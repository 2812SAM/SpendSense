import '../../models/transaction.dart';
import '../../models/insight_finding.dart';
import '../../models/savings_opportunity.dart';
import '../../models/user_goals.dart';
import '../../models/expense_classification.dart';
import '../../providers/classification_provider.dart';

class InsightsRuleEngine {
  static List<InsightFinding> evaluateRules(
    List<MyTransaction> transactions,
    UserGoals goals,
    ClassificationProvider? classifications,
  ) {
    final findings = <InsightFinding>[];
    if (transactions.isEmpty) return findings;

    // Fallback if no goals are set: Phase 2 legacy logic
    if (goals.monthlyTotalLimit == 0 && goals.categoryLimits.isEmpty) {
      return _legacyEvaluateRules(transactions);
    }

    var sometimeTransactions = transactions;
    var recurringTransactions = <MyTransaction>[];

    if (classifications != null) {
      sometimeTransactions = transactions
          .where((t) =>
              classifications.natureOf(t.merchant, t.category) ==
              ExpenseNature.sometime)
          .toList();
      recurringTransactions = transactions
          .where((t) =>
              classifications.natureOf(t.merchant, t.category) ==
              ExpenseNature.recurring)
          .toList();
    }

    // Adaptive Rules (Phase 2.5 + Classification)
    findings.addAll(_evaluateHabitualOverspend(sometimeTransactions, goals));

    final burnRate =
        _evaluateBurnRate(sometimeTransactions, recurringTransactions, goals);
    if (burnRate != null) findings.add(burnRate);

    final safeAnomaly = _evaluateSafeAnomaly(
        sometimeTransactions, recurringTransactions, goals);
    if (safeAnomaly != null) findings.add(safeAnomaly);

    if (classifications != null) {
      findings.addAll(
          _evaluateRecurringAnomaly(recurringTransactions, classifications));
    }

    return findings;
  }

  static List<SavingsOpportunity> evaluateSavings(
    List<MyTransaction> transactions,
    UserGoals goals,
    ClassificationProvider? classifications,
  ) {
    final opportunities = <SavingsOpportunity>[];
    if (transactions.isEmpty) return opportunities;

    var sometimeTransactions = transactions;
    if (classifications != null) {
      sometimeTransactions = transactions
          .where((t) =>
              classifications.natureOf(t.merchant, t.category) ==
              ExpenseNature.sometime)
          .toList();
    }

    final foodDelivery = _generateFoodDeliverySavings(sometimeTransactions);
    if (foodDelivery != null) opportunities.add(foodDelivery);

    return opportunities;
  }

  static List<InsightFinding> _legacyEvaluateRules(
      List<MyTransaction> transactions) {
    final findings = <InsightFinding>[];
    final weekendSpike = _evaluateWeekendSpikes(transactions);
    if (weekendSpike != null) findings.add(weekendSpike);

    final lateNight = _evaluateLateNight(transactions);
    if (lateNight != null) findings.add(lateNight);

    findings.addAll(_evaluateCategoryTrends(transactions));
    return findings;
  }

  static List<InsightFinding> _evaluateHabitualOverspend(
      List<MyTransaction> transactions, UserGoals goals) {
    final findings = <InsightFinding>[];

    for (final entry in goals.categoryLimits.entries) {
      final category = entry.key;
      final goal = entry.value;
      if (goal == 0) continue; // skip unconfigured categories

      // Only check sometime transactions for this category
      final categoryTxns =
          transactions.where((t) => t.category == category).toList();
      final avg3Month = _getAverage3MonthSpend(categoryTxns);

      if (avg3Month > goal * 1.1) {
        findings.add(InsightFinding(
          id: 'habitual_overspend_$category',
          emoji: _getEmojiForCategory(category),
          title: '$category habit over limit',
          description:
              'You consistently spend ₹${(avg3Month - goal).toStringAsFixed(0)} above your $category target. This is a recurring pattern.',
          trend: InsightTrend.up,
          severity: InsightSeverity.high,
        ));
      }
    }
    return findings;
  }

  static InsightFinding? _evaluateBurnRate(
      List<MyTransaction> sometimeTransactions,
      List<MyTransaction> recurringTransactions,
      UserGoals goals) {
    if (goals.monthlyTotalLimit > 0) {
      final today = DateTime.now();
      final dayOfMonth = today.day;

      // Calculate days in month manually
      final firstOfNextMonth = DateTime(today.year, today.month + 1, 1);
      final lastOfThisMonth =
          firstOfNextMonth.subtract(const Duration(days: 1));
      final daysInMonth = lastOfThisMonth.day;

      final sometimeSpend = _getCurrentMonthTotal(sometimeTransactions);
      final recurringCommitted = _getCurrentMonthTotal(recurringTransactions);
      final effectiveLimit = goals.monthlyTotalLimit - recurringCommitted;

      final projected = (sometimeSpend / dayOfMonth) * daysInMonth;

      if (projected > effectiveLimit) {
        return InsightFinding(
          id: 'burn_rate',
          emoji: '🔥',
          title: 'Burn rate warning',
          description:
              'After your fixed payments (₹${recurringCommitted.toStringAsFixed(0)}), you have ₹${effectiveLimit.toStringAsFixed(0)} for flexible spending. At this pace you will exceed that by ₹${(projected - effectiveLimit).toStringAsFixed(0)}.',
          trend: InsightTrend.up,
          severity: InsightSeverity.medium,
        );
      }
    }
    return null;
  }

  static InsightFinding? _evaluateSafeAnomaly(
      List<MyTransaction> sometimeTransactions,
      List<MyTransaction> recurringTransactions,
      UserGoals goals) {
    final spikeDetected = _evaluateWeekendSpikes(sometimeTransactions) != null;
    final sometimeSpend = _getCurrentMonthTotal(sometimeTransactions);
    final recurringCommitted = _getCurrentMonthTotal(recurringTransactions);
    final effectiveLimit = goals.monthlyTotalLimit - recurringCommitted;

    if (spikeDetected &&
        effectiveLimit > 0 &&
        sometimeSpend < effectiveLimit * 0.8) {
      return const InsightFinding(
        id: 'safe_anomaly',
        emoji: '👍',
        title: 'Safe anomaly detected',
        description:
            'You had a high-spend period, but you\'re still well within your flexible budget. You\'re on track!',
        trend: InsightTrend.stable,
        severity: InsightSeverity.low,
      );
    }
    return null;
  }

  static List<InsightFinding> _evaluateRecurringAnomaly(
      List<MyTransaction> recurringTransactions,
      ClassificationProvider classifications) {
    final findings = <InsightFinding>[];

    // Only look at current month
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final monthTxs = recurringTransactions
        .where((tx) =>
            tx.timestamp.isAfter(firstOfMonth) ||
            tx.timestamp.isAtSameMomentAs(firstOfMonth))
        .toList();

    for (final t in monthTxs) {
      final expected = classifications.expectedAmountOf(t.merchant, t.category);
      if (expected == null || expected == 0) {
        continue; // variable recurring — skip amount check
      }

      final diff = t.amount - expected;
      if (diff.abs() > expected * 0.05) {
        findings.add(InsightFinding(
          id: 'recurring_anomaly_${t.id}',
          emoji: '⚠️',
          title: 'Recurring bill change',
          description:
              '${t.category} payment this month is ₹${diff.abs().toStringAsFixed(0)} ${diff > 0 ? "higher" : "lower"} than usual.',
          trend: diff > 0 ? InsightTrend.up : InsightTrend.down,
          severity: InsightSeverity.medium,
        ));
      }
    }
    return findings;
  }

  static double _getAverage3MonthSpend(List<MyTransaction> transactions) {
    final now = DateTime.now();
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));
    final catTxs =
        transactions.where((tx) => tx.timestamp.isAfter(ninetyDaysAgo));
    final total = catTxs.fold(0.0, (sum, tx) => sum + tx.amount);
    return total / 3.0; // 3 months
  }

  static double _getCurrentMonthTotal(List<MyTransaction> transactions) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final monthTxs = transactions.where((tx) =>
        tx.timestamp.isAfter(firstOfMonth) ||
        tx.timestamp.isAtSameMomentAs(firstOfMonth));
    return monthTxs.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  static InsightFinding? _evaluateWeekendSpikes(
      List<MyTransaction> transactions) {
    final now = DateTime.now();
    final thirtyDaysAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 30));

    final recentTxs = transactions
        .where((tx) =>
            tx.timestamp.isAfter(thirtyDaysAgo) ||
            tx.timestamp.isAtSameMomentAs(thirtyDaysAgo))
        .toList();
    if (recentTxs.isEmpty) return null;

    var weekendSpend = 0.0;
    var weekdaySpend = 0.0;
    var weekendDays = 0;
    var weekdayDays = 0;

    // Calculate actual days in the period
    for (var i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        weekendDays++;
      } else {
        weekdayDays++;
      }
    }

    for (final tx in recentTxs) {
      if (tx.timestamp.weekday == DateTime.saturday ||
          tx.timestamp.weekday == DateTime.sunday) {
        weekendSpend += tx.amount;
      } else {
        weekdaySpend += tx.amount;
      }
    }

    if (weekendDays == 0 || weekdayDays == 0) return null;

    final avgWeekendSpend = weekendSpend / weekendDays;
    final avgWeekdaySpend = weekdaySpend / weekdayDays;

    if (weekendSpend > 2000 && avgWeekendSpend > (avgWeekdaySpend * 1.5)) {
      return InsightFinding(
        id: 'weekend_spike',
        emoji: '📊',
        title: 'Weekend spending spikes are affecting savings',
        description:
            'Your weekend spending averages ₹${avgWeekendSpend.toStringAsFixed(0)} vs weekday ₹${avgWeekdaySpend.toStringAsFixed(0)}.',
        trend: InsightTrend.up,
        severity: InsightSeverity.high,
      );
    }
    return null;
  }

  static InsightFinding? _evaluateLateNight(List<MyTransaction> transactions) {
    final now = DateTime.now();
    final thirtyDaysAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 30));

    final recentTxs = transactions
        .where((tx) =>
            tx.timestamp.isAfter(thirtyDaysAgo) ||
            tx.timestamp.isAtSameMomentAs(thirtyDaysAgo))
        .toList();
    if (recentTxs.isEmpty) return null;

    var totalSpend = 0.0;
    var lateNightSpend = 0.0;

    for (final tx in recentTxs) {
      totalSpend += tx.amount;
      if (tx.timestamp.hour >= 22 || tx.timestamp.hour < 4) {
        lateNightSpend += tx.amount;
      }
    }

    if (totalSpend > 0 &&
        lateNightSpend > 1000 &&
        (lateNightSpend / totalSpend) > 0.20) {
      return InsightFinding(
        id: 'late_night',
        emoji: '🌙',
        title: 'High late-night spending detected',
        description:
            'You spent ₹${lateNightSpend.toStringAsFixed(0)} between 10 PM and 4 AM recently. This is ${(lateNightSpend / totalSpend * 100).toStringAsFixed(0)}% of your total spend.',
        trend: InsightTrend.up,
        severity: InsightSeverity.medium,
      );
    }
    return null;
  }

  static List<InsightFinding> _evaluateCategoryTrends(
      List<MyTransaction> transactions) {
    final findings = <InsightFinding>[];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
    final fourteenDaysAgo = todayStart.subtract(const Duration(days: 14));

    const discretionaryCategories = [
      'Food',
      'Shopping',
      'Fun',
      'Entertainment'
    ];

    for (final category in discretionaryCategories) {
      final currentWeekAmount = transactions
          .where((tx) =>
              tx.category == category &&
              (tx.timestamp.isAfter(sevenDaysAgo) ||
                  tx.timestamp.isAtSameMomentAs(sevenDaysAgo)))
          .fold(0.0, (sum, tx) => sum + tx.amount);

      final previousWeekAmount = transactions
          .where((tx) =>
              tx.category == category &&
              tx.timestamp.isAfter(fourteenDaysAgo) &&
              tx.timestamp.isBefore(sevenDaysAgo))
          .fold(0.0, (sum, tx) => sum + tx.amount);

      if (previousWeekAmount > 0) {
        final increase = currentWeekAmount - previousWeekAmount;
        final percentIncrease = (increase / previousWeekAmount) * 100;

        if (percentIncrease > 25 && increase > 500) {
          findings.add(InsightFinding(
            id: 'cat_trend_$category',
            emoji: _getEmojiForCategory(category),
            title: '$category spending increased',
            description:
                'You spent ₹${increase.toStringAsFixed(0)} more on $category this week compared to last week.',
            trend: InsightTrend.up,
            severity: InsightSeverity.medium,
          ));
        }
      }
    }

    return findings;
  }

  static SavingsOpportunity? _generateFoodDeliverySavings(
      List<MyTransaction> transactions) {
    final now = DateTime.now();
    final thirtyDaysAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 30));

    final recentFoodTxs = transactions
        .where((tx) =>
            tx.category == 'Food' &&
            tx.amount < 600 &&
            (tx.timestamp.isAfter(thirtyDaysAgo) ||
                tx.timestamp.isAtSameMomentAs(thirtyDaysAgo)))
        .toList();

    final frequency = recentFoodTxs.length;

    if (frequency > 6) {
      final totalAmount = recentFoodTxs.fold(0.0, (sum, tx) => sum + tx.amount);
      final avgOrderValue = totalAmount / frequency;
      const targetFrequency = 4;
      final potentialSavings = (frequency - targetFrequency) * avgOrderValue;

      return SavingsOpportunity(
        id: 'food_delivery_freq',
        emoji: '🚚',
        title: 'Reduce food delivery frequency',
        description:
            'You ordered food $frequency times recently. Limiting this to $targetFrequency times/month could save you money.',
        potentialAmount: '₹${potentialSavings.toStringAsFixed(0)}/mo',
      );
    }
    return null;
  }

  static String _getEmojiForCategory(String category) {
    switch (category) {
      case 'Food':
        return '🍔';
      case 'Shopping':
        return '🛍️';
      case 'Fun':
      case 'Entertainment':
        return '🎭';
      default:
        return '📈';
    }
  }
}
