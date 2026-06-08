import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/expense_classification.dart';
import '../services/local_storage_service.dart';

class ClassificationRepository {
  final LocalStorageService _local;

  ClassificationRepository(this._local);

  Future<List<ExpenseClassification>> getAll() async {
    final db = await _local.database;
    final rows = await db.query('expense_classifications');
    return rows
        .map((row) => ExpenseClassification(
              merchantOrCategory: row['merchant_or_category'] as String,
              nature: (row['nature'] as String) == 'recurring'
                  ? ExpenseNature.recurring
                  : ExpenseNature.sometime,
              expectedAmount: row['expected_amount'] != null
                  ? (row['expected_amount'] as num).toDouble()
                  : null,
              userConfirmed: (row['user_confirmed'] as int) == 1,
            ))
        .toList();
  }

  Future<void> save(ExpenseClassification c) async {
    final db = await _local.database;
    await db.insert(
      'expense_classifications',
      {
        'merchant_or_category': c.merchantOrCategory,
        'nature': c.nature.name,
        'expected_amount': c.expectedAmount,
        'user_confirmed': c.userConfirmed ? 1 : 0,
        'last_updated': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAll(List<ExpenseClassification> classifications) async {
    final db = await _local.database;
    final batch = db.batch();
    for (final c in classifications) {
      batch.insert(
        'expense_classifications',
        {
          'merchant_or_category': c.merchantOrCategory,
          'nature': c.nature.name,
          'expected_amount': c.expectedAmount,
          'user_confirmed': c.userConfirmed ? 1 : 0,
          'last_updated': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
