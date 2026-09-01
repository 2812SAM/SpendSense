import '../local_storage_service.dart';
import '../../models/insights_snapshot.dart';
import '../../models/user_goals.dart';
import '../../core/constants.dart';
import '../../providers/classification_provider.dart';
import 'insights_metrics_engine.dart';
import 'insights_rule_engine.dart';

class InsightsService {
  final LocalStorageService _storage;

  InsightsService({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance;

  Future<InsightsSnapshot> generateSnapshot({
    UserGoals? goals,
    ClassificationProvider? classifications,
  }) async {
    // Phase 1: Use only confirmed transactions
    // For V1, we read the last 90 days of transactions to cover WoW and MoM comparisons.
    final allConfirmed = (await _storage.getRecentConfirmed(limit: 500))
        .where((tx) => tx.category != AppConstants.categoryIgnored)
        .toList(); // Reasonable limit for local analysis

    if (allConfirmed.isEmpty) {
      return InsightsSnapshot.empty();
    }

    final weeklySpending =
        InsightsMetricsEngine.computeWeeklySpending(allConfirmed);
    final monthlyTrend =
        InsightsMetricsEngine.computeMonthlyTrend(allConfirmed);
    final topCategories =
        InsightsMetricsEngine.computeTopCategories(allConfirmed);
    final weeklyImprovement =
        InsightsMetricsEngine.computeWeeklyImprovement(allConfirmed);
    final monthTrend = InsightsMetricsEngine.computeMonthTrend(allConfirmed);

    // Phase 2.5: Rule Engine (Adaptive)
    final findings = InsightsRuleEngine.evaluateRules(
      allConfirmed,
      goals ?? UserGoals.empty(),
      classifications,
    );
    final savingsOpportunities = InsightsRuleEngine.evaluateSavings(
      allConfirmed,
      goals ?? UserGoals.empty(),
      classifications,
    );

    // Phase 1: Health score and status are placeholders until Phase 3
    // But we can derive a very basic status from weekly improvement.
    var healthStatus = 'Fair';
    var healthScore = 65;

    if (weeklyImprovement > 15) {
      healthStatus = 'Excellent';
      healthScore = 85;
    } else if (weeklyImprovement > 5) {
      healthStatus = 'Improving';
      healthScore = 75;
    } else if (weeklyImprovement < -10) {
      healthStatus = 'Needs Attention';
      healthScore = 50;
    }

    return InsightsSnapshot(
      healthScore: healthScore,
      healthStatus: healthStatus,
      weeklyImprovement: weeklyImprovement,
      monthTrend: monthTrend,
      weeklySpending: weeklySpending,
      monthlyTrend: monthlyTrend,
      topCategories: topCategories,
      findings: findings,
      savingsOpportunities: savingsOpportunities,
      timestamp: DateTime.now(),
      isInitialised: true,
    );
  }
}
