import 'package:flutter/material.dart';
import '../models/insights_snapshot.dart';
import '../models/user_goals.dart';
import '../services/insights/insights_service.dart';
import 'classification_provider.dart';

class InsightsProvider extends ChangeNotifier {
  final InsightsService _service;
  UserGoals _goals;
  ClassificationProvider? _classifications;
  InsightsSnapshot _snapshot = InsightsSnapshot.empty();
  bool _isLoading = false;

  InsightsProvider(this._service, this._goals);

  InsightsSnapshot get snapshot => _snapshot;
  bool get isLoading => _isLoading;

  void onContextUpdated(
      UserGoals newGoals, ClassificationProvider newClassifications) {
    var changed = false;

    // Very simple dirty check, can be refined later if needed
    if (_goals.monthlyTotalLimit != newGoals.monthlyTotalLimit ||
        _goals.categoryLimits.length != newGoals.categoryLimits.length ||
        _classifications?.classifications.length !=
            newClassifications.classifications.length) {
      changed = true;
    }

    _goals = newGoals;
    _classifications = newClassifications;

    if (changed) {
      debugPrint('SpendSense: InsightsProvider.onContextUpdated fired.');
      refresh();
    }
  }

  Future<void> refresh() async {
    if (_classifications == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _snapshot = await _service.generateSnapshot(
        goals: _goals,
        classifications: _classifications,
      );
    } catch (e) {
      debugPrint('SpendSense Error: Failed to refresh insights: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
