import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/user_goals.dart';
import '../services/local_storage_service.dart';

class GoalsRepository {
  final LocalStorageService _local;

  GoalsRepository(this._local);

  Future<UserGoals> getGoals() async {
    final db = await _local.database;
    final totalRow = await db.query('user_goals', where: 'id = 1', limit: 1);
    final categoryRows = await db.query('category_goals');

    final monthlyLimit = totalRow.isEmpty
        ? 0.0
        : (totalRow.first['monthly_total_limit'] as num).toDouble();

    final categoryLimits = {
      for (final row in categoryRows)
        row['category_name'] as String: (row['monthly_limit'] as num).toDouble()
    };

    return UserGoals(
      monthlyTotalLimit: monthlyLimit,
      categoryLimits: categoryLimits,
    );
  }

  Future<void> setMonthlyLimit(double limit) async {
    final db = await _local.database;
    await db.update(
      'user_goals',
      {
        'monthly_total_limit': limit,
        'last_updated': DateTime.now().toIso8601String(),
      },
      where: 'id = 1',
    );
  }

  Future<void> setCategoryLimit(String category, double limit) async {
    final db = await _local.database;
    await db.insert(
      'category_goals',
      {
        'category_name': category,
        'monthly_limit': limit,
        'last_updated': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
