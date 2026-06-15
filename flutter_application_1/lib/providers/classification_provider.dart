import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/expense_classification.dart';
import '../repositories/classification_repository.dart';
import '../services/insights/classification_detector.dart';

class ClassificationProvider extends ChangeNotifier {
  final ClassificationRepository _repo;
  final ClassificationDetector _detector;
  List<ExpenseClassification> _classifications = [];
  List<ExpenseClassification> _pendingConfirmation = [];

  ClassificationProvider(this._repo, this._detector);

  List<ExpenseClassification> get classifications => _classifications;
  List<ExpenseClassification> get pendingConfirmation => _pendingConfirmation;
  bool get hasPendingConfirmations => _pendingConfirmation.isNotEmpty;

  Future<void> init(List<MyTransaction> transactionHistory) async {
    _classifications = await _repo.getAll();

    // Only run auto-detection if we have no confirmed classifications yet
    final hasConfirmed = _classifications.any((c) => c.userConfirmed);
    if (!hasConfirmed) {
      final detected = _detector.detect(transactionHistory);
      // Only surface ones not already classified
      final existingKeys =
          _classifications.map((c) => c.merchantOrCategory).toSet();
      _pendingConfirmation = detected
          .where((d) => !existingKeys.contains(d.merchantOrCategory))
          .toList();
    }

    notifyListeners();
  }

  ExpenseNature natureOf(String merchant, String category) {
    // 1. Check if the specific merchant was classified
    final merchantMatch = _classifications
        .where((c) => c.merchantOrCategory == merchant)
        .firstOrNull;
    if (merchantMatch != null) return merchantMatch.nature;

    // 2. Check if the whole category was classified
    final categoryMatch = _classifications
        .where((c) => c.merchantOrCategory == category)
        .firstOrNull;

    return categoryMatch?.nature ?? ExpenseNature.sometime; // default: sometime
  }

  double? expectedAmountOf(String merchant, String category) {
    final merchantMatch = _classifications
        .where((c) => c.merchantOrCategory == merchant)
        .firstOrNull;
    if (merchantMatch != null) return merchantMatch.expectedAmount;

    final categoryMatch = _classifications
        .where((c) => c.merchantOrCategory == category)
        .firstOrNull;

    return categoryMatch?.expectedAmount;
  }

  Future<void> confirmDetected(List<ExpenseClassification> confirmed) async {
    final toSave = confirmed
        .map((c) => ExpenseClassification(
              merchantOrCategory: c.merchantOrCategory,
              nature: c.nature,
              expectedAmount: c.expectedAmount,
              userConfirmed: true,
            ))
        .toList();
    await _repo.saveAll(toSave);
    _classifications = [..._classifications, ...toSave];
    _pendingConfirmation = [];
    notifyListeners();
  }

  Future<void> setClassification(
    String merchantOrCategory,
    ExpenseNature nature, {
    double? expectedAmount,
  }) async {
    final c = ExpenseClassification(
      merchantOrCategory: merchantOrCategory,
      nature: nature,
      expectedAmount: expectedAmount,
      userConfirmed: true,
    );
    await _repo.save(c);
    _classifications = [
      ..._classifications
          .where((e) => e.merchantOrCategory != merchantOrCategory),
      c,
    ];
    notifyListeners();
  }

  void dismissPendingConfirmation() {
    _pendingConfirmation = [];
    notifyListeners();
  }
}
