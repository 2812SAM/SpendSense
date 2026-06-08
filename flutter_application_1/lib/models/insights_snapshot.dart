import 'package:flutter/material.dart';
import 'insight_finding.dart';
import 'savings_opportunity.dart';

class InsightsSnapshot {
  final int healthScore;
  final String healthStatus;
  final double weeklyImprovement; // Percentage
  final double monthTrend; // Percentage
  final List<SpendingDatum> weeklySpending;
  final List<SpendingDatum> monthlyTrend;
  final List<CategoryInsight> topCategories;
  final List<InsightFinding> findings;
  final List<SavingsOpportunity> savingsOpportunities;
  final DateTime timestamp;
  final bool isInitialised;

  const InsightsSnapshot({
    required this.healthScore,
    required this.healthStatus,
    required this.weeklyImprovement,
    required this.monthTrend,
    required this.weeklySpending,
    required this.monthlyTrend,
    required this.topCategories,
    required this.findings,
    required this.savingsOpportunities,
    required this.timestamp,
    this.isInitialised = true,
  });

  factory InsightsSnapshot.empty() {
    return InsightsSnapshot(
      healthScore: 0,
      healthStatus: 'No Data',
      weeklyImprovement: 0,
      monthTrend: 0,
      weeklySpending: [],
      monthlyTrend: [],
      topCategories: [],
      findings: [],
      savingsOpportunities: [],
      timestamp: DateTime.now(),
      isInitialised: false,
    );
  }
}

class SpendingDatum {
  final String label;
  final double amount;

  const SpendingDatum({
    required this.label,
    required this.amount,
  });
}

class CategoryInsight {
  final String name;
  final double amount;
  final double trend; // Percentage
  final Color color;

  const CategoryInsight({
    required this.name,
    required this.amount,
    required this.trend,
    required this.color,
  });
}
