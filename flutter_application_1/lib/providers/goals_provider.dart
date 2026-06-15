import 'package:flutter/foundation.dart';
import '../models/user_goals.dart';
import '../repositories/goals_repository.dart';

class GoalsProvider extends ChangeNotifier {
  final GoalsRepository _repo;
  UserGoals _goals = UserGoals.empty();

  GoalsProvider(this._repo) {
    _load();
  }

  UserGoals get currentGoals => _goals;

  Future<void> _load() async {
    _goals = await _repo.getGoals();
    notifyListeners();
  }

  Future<void> updateMonthlyLimit(double limit) async {
    await _repo.setMonthlyLimit(limit);
    _goals = UserGoals(
      monthlyTotalLimit: limit,
      categoryLimits: _goals.categoryLimits,
    );
    notifyListeners();
  }

  Future<void> updateCategoryLimit(String category, double limit) async {
    await _repo.setCategoryLimit(category, limit);
    final updated = Map<String, double>.from(_goals.categoryLimits)
      ..[category] = limit;
    _goals = UserGoals(
      monthlyTotalLimit: _goals.monthlyTotalLimit,
      categoryLimits: updated,
    );
    notifyListeners();
  }
}
