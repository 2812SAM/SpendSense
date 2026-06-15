class UserGoals {
  final double monthlyTotalLimit;
  final Map<String, double> categoryLimits;

  const UserGoals({
    required this.monthlyTotalLimit,
    required this.categoryLimits,
  });

  factory UserGoals.empty() =>
      const UserGoals(monthlyTotalLimit: 0, categoryLimits: {});

  @override
  String toString() {
    return 'UserGoals(total: $monthlyTotalLimit, categories: $categoryLimits)';
  }
}
