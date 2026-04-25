import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendsense/services/recent_transactions_service.dart';
import 'package:spendsense/services/local_storage_service.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/core/constants.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late RecentTransactionsService service;
  late LocalStorageService storage;

  setUp(() async {
    // Use in-memory DB for tests
    storage = LocalStorageService(dbName: ':memory:');
    // RecentTransactionsService uses the Singleton instance of LocalStorageService 
    // internally. To test it, we must ensure the singleton uses our in-memory DB.
    // In a full DI refactor, we would pass the storage instance into the service.
    // For now, let's just use the default instance and clear it.
    
    // NOTE: This highlights the need for full DI refactor.
    storage = LocalStorageService.instance;
    final db = await storage.database;
    await db.delete(AppConstants.transactionsTable);
    
    service = RecentTransactionsService.instance;
  });

  test('fetchMonthlySummary should correctly aggregate expenses', () async {
    final now = DateTime.now();
    final tx1 = MyTransaction(
      id: '1', timestamp: now, amount: 100, merchant: 'M1', 
      category: 'Food', confidence: 'HIGH', type: 'EXPENSE', isConfirmed: true,
    );
    final tx2 = MyTransaction(
      id: '2', timestamp: now, amount: 200, merchant: 'M2', 
      category: 'Food', confidence: 'HIGH', type: 'EXPENSE', isConfirmed: true,
    );
    final tx3 = MyTransaction(
      id: '3', timestamp: now, amount: 50, merchant: 'M3', 
      category: 'Health', confidence: 'HIGH', type: 'EXPENSE', isConfirmed: true,
    );
    // Should be ignored (Loan)
    final tx4 = MyTransaction(
      id: '4', timestamp: now, amount: 1000, merchant: 'M4', 
      category: 'Loan', confidence: 'HIGH', type: 'LOAN', isConfirmed: true,
    );

    await storage.upsertTransaction(tx1, needsUserInput: false);
    await storage.upsertTransaction(tx2, needsUserInput: false);
    await storage.upsertTransaction(tx3, needsUserInput: false);
    await storage.upsertTransaction(tx4, needsUserInput: false);

    final summary = await service.fetchMonthlySummary();

    expect(summary.totalSpent, 350.0);
    expect(summary.txCount, 3);
    expect(summary.byCategory['Food'], 300.0);
    expect(summary.byCategory['Health'], 50.0);
    expect(summary.topCategory, 'Food');
  });
}
