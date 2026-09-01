import '../../models/transaction.dart';
import '../../models/expense_classification.dart';

class ClassificationDetector {
  /// Returns auto-detected classifications for review.
  /// Does NOT write to DB — caller decides whether to save.
  List<ExpenseClassification> detect(List<MyTransaction> history) {
    final results = <ExpenseClassification>[];
    if (history.isEmpty) return results;

    final now = DateTime.now();

    // Group transactions by merchant
    final byMerchant = <String, List<MyTransaction>>{};
    for (final t in history) {
      byMerchant.putIfAbsent(t.merchant, () => []).add(t);
    }

    for (final entry in byMerchant.entries) {
      final merchant = entry.key;
      final txns = entry.value;

      // Sort chronologically
      txns.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (_isLikelyRecurring(txns, now)) {
        final amounts = txns.map((t) => t.amount).toList();
        final avg = amounts.reduce((a, b) => a + b) / amounts.length;
        final variance =
            amounts.map((a) => (a - avg).abs()).reduce((a, b) => a + b) /
                amounts.length;
        final isFixed =
            variance < avg * 0.05; // less than 5% variance = fixed amount

        results.add(ExpenseClassification(
          merchantOrCategory: merchant,
          nature: ExpenseNature.recurring,
          expectedAmount:
              isFixed ? avg : null, // null for variable like electricity
          userConfirmed: false,
        ));
      }
      // else: default is 'sometime', no need to store (engine uses sometime as fallback)
    }

    return results;
  }

  bool _isLikelyRecurring(List<MyTransaction> txns, DateTime now) {
    if (txns.length < 2) return false;

    // 1. Recency Filter
    // If the most recent transaction is older than 45 days, ignore it (inactive subscription).
    final mostRecent = txns.last.timestamp;
    if (now.difference(mostRecent).inDays > 45) {
      return false;
    }

    // 2. Cadence Filter (The Rhythm Test)
    // Calculate days between consecutive transactions
    final gaps = <int>[];
    for (var i = 1; i < txns.length; i++) {
      gaps.add(
          txns[i].timestamp.difference(txns[i - 1].timestamp).inDays.abs());
    }

    // Check for monthly rhythm (roughly 28-31 days)
    var monthlyRhythmCount = 0;
    for (final gap in gaps) {
      if (gap >= 27 && gap <= 33) {
        monthlyRhythmCount++;
      }
    }

    // Check for annual rhythm (roughly 360-370 days)
    var annualRhythmCount = 0;
    for (final gap in gaps) {
      if (gap >= 360 && gap <= 370) {
        annualRhythmCount++;
      }
    }

    // Minimum thresholds for confidence
    if (monthlyRhythmCount >= 1) {
      // Needs at least one 1-month gap (i.e. 2 transactions)
      return true;
    }

    if (annualRhythmCount >= 1) {
      return true;
    }

    return false;
  }
}
