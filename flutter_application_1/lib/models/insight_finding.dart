enum InsightTrend { up, down, stable }

enum InsightSeverity { low, medium, high }

class InsightFinding {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final InsightTrend trend;
  final InsightSeverity severity;

  const InsightFinding({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.trend,
    required this.severity,
  });
}
