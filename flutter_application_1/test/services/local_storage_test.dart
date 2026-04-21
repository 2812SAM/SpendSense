import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendsense/services/local_storage_service.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/core/constants.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalStorageService storage;

  setUp(() async {
    storage = LocalStorageService.instance;
    final db = await storage.database;
    await db.delete(AppConstants.transactionsTable);
    await db.delete('merchant_memory');
    await db.delete('custom_categories');
  });

  group('LocalStorageService - Transactions', () {
    test('upsertTransaction should save and findByFingerprint should retrieve', () async {
      final tx = MyTransaction(
        id: 'tx_123',
        timestamp: DateTime.now(),
        amount: 100.0,
        merchant: 'Test Merchant',
        category: 'Food',
        confidence: AppConstants.confidenceHigh,
        type: AppConstants.typeExpense,
        note: 'Test',
        rawSms: 'Test SMS',
        isConfirmed: true,
      );
      const fingerprint = 'fp_1';

      await storage.upsertTransaction(tx, needsUserInput: false, fingerprint: fingerprint);
      final retrieved = await storage.findByFingerprint(fingerprint);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, tx.id);
    });

    test('getPending should return only transactions needing input', () async {
      final tx1 = MyTransaction(id: '1', timestamp: DateTime.now(), amount: 10, merchant: 'A', category: 'Food', confidence: 'LOW', type: 'EXPENSE', note: '', rawSms: '');
      final tx2 = MyTransaction(id: '2', timestamp: DateTime.now(), amount: 20, merchant: 'B', category: 'Food', confidence: 'HIGH', type: 'EXPENSE', note: '', rawSms: '', isConfirmed: true);

      await storage.upsertTransaction(tx1, needsUserInput: true);
      await storage.upsertTransaction(tx2, needsUserInput: false);

      final pending = await storage.getPending();
      expect(pending.length, 1);
      expect(pending.first.id, '1');
    });

    test('markConfirmed and markSynced should update status', () async {
      final tx = MyTransaction(id: 'sync_test', timestamp: DateTime.now(), amount: 50, merchant: 'M', category: 'Others', confidence: 'LOW', type: 'EXPENSE', note: '', rawSms: '');
      await storage.upsertTransaction(tx, needsUserInput: true);

      await storage.markConfirmed('sync_test', category: 'Food', type: 'EXPENSE', note: 'Updated');
      var updated = await storage.findTransactionById('sync_test');
      expect(updated!.isConfirmed, isTrue);
      expect(updated.category, 'Food');

      await storage.markSynced('sync_test');
      updated = await storage.findTransactionById('sync_test');
      expect(updated!.isLogged, isTrue);
      expect(updated.syncStatus, AppConstants.syncSynced);
    });

    test('getUnsynced should return transactions that failed or are pending', () async {
      final tx = MyTransaction(id: 'unsynced', timestamp: DateTime.now(), amount: 50, merchant: 'M', category: 'Food', confidence: 'HIGH', type: 'EXPENSE', note: '', rawSms: '', isConfirmed: true);
      await storage.upsertTransaction(tx, needsUserInput: false, syncStatus: AppConstants.syncPending);
      
      final unsynced = await storage.getUnsynced();
      expect(unsynced.any((t) => t.id == 'unsynced'), isTrue);
    });
  });

  group('LocalStorageService - Merchant Memory', () {
    test('saveMerchantMemory should persist and lookupMerchant should retrieve', () async {
      await storage.saveMerchantMemory('Starbucks', 'Food', 'EXPENSE');
      
      final memory = await storage.lookupMerchant('starbucks'); // Test normalization
      expect(memory, isNotNull);
      expect(memory!.category, 'Food');
      expect(memory.merchantKey, 'starbucks');
    });

    test('multiple saves should increment count in merchant memory', () async {
      await storage.saveMerchantMemory('Zomato', 'Food', 'EXPENSE');
      await storage.saveMerchantMemory('Zomato', 'Food', 'EXPENSE');
      
      final memory = await storage.lookupMerchant('zomato');
      expect(memory!.count, 2);
    });
  });

  group('LocalStorageService - Custom Categories', () {
    test('saveCustomCategory and getCustomCategories should work', () async {
      await storage.saveCustomCategory('Gym');
      await storage.saveCustomCategory('Investment');

      final categories = await storage.getCustomCategories();
      expect(categories, contains('Gym'));
      expect(categories, contains('Investment'));
      expect(categories.length, 2);
    });
  });
}
