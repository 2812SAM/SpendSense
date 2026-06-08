import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendsense/services/local_storage_service.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/core/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStorageService storage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    storage = LocalStorageService(
      dbName: ':memory:',
      databaseFactory: databaseFactoryFfi,
      password: '', // Use empty password for FFI unit tests
    );
    await storage.database;
  });

  group('Category Management - Core Logic', () {
    test('Should create and retrieve custom category with emoji', () async {
      await storage.saveCustomCategory('Gym', emoji: '🏋️');
      final categories = await storage.getCustomCategories();

      final gym = categories.firstWhere((c) => c['name'] == 'Gym');
      expect(gym['emoji'], '🏋️');
    });

    test('Renaming category should cascade to transactions and merchant memory',
        () async {
      // 1. Setup initial data
      await storage.saveCustomCategory('Gym', emoji: '🏋️');

      final tx = MyTransaction(
        id: 'tx1',
        timestamp: DateTime.now(),
        amount: 500,
        merchant: 'Gold Gym',
        category: 'Gym',
        confidence: AppConstants.confidenceHigh,
        type: AppConstants.typeExpense,
      );
      await storage.upsertTransaction(tx, needsUserInput: false);
      await storage.saveMerchantMemory(
          'Gold Gym', 'Gym', AppConstants.typeExpense);

      // 2. Perform rename
      await storage.renameCategory('Gym', 'Fitness');

      // 3. Verify cascading
      final updatedTx = await storage.findTransactionById('tx1');
      expect(updatedTx?.category, 'Fitness');

      final memory = await storage.lookupMerchant('Gold Gym');
      expect(memory?.category, 'Fitness');

      final categories = await storage.getCustomCategories();
      expect(categories.any((c) => c['name'] == 'Gym'), isFalse);
      expect(categories.any((c) => c['name'] == 'Fitness'), isTrue);
    });

    test('Should prevent deletion of category with existing transactions',
        () async {
      await storage.saveCustomCategory('Gym', emoji: '🏋️');
      final tx = MyTransaction(
        id: 'tx1',
        timestamp: DateTime.now(),
        amount: 500,
        merchant: 'Gold Gym',
        category: 'Gym',
        confidence: AppConstants.confidenceHigh,
        type: AppConstants.typeExpense,
      );
      await storage.upsertTransaction(tx, needsUserInput: false);

      // Attempt deletion
      expect(
        () => storage.deleteCategory('Gym'),
        throwsA(isA<Exception>()),
      );
    });

    test('Should allow deletion after reassigning transactions', () async {
      await storage.saveCustomCategory('Gym', emoji: '🏋️');
      await storage.saveCustomCategory('Others', emoji: '📦');

      final tx = MyTransaction(
        id: 'tx1',
        timestamp: DateTime.now(),
        amount: 500,
        merchant: 'Gold Gym',
        category: 'Gym',
        confidence: AppConstants.confidenceHigh,
        type: AppConstants.typeExpense,
      );
      await storage.upsertTransaction(tx, needsUserInput: false);

      // Reassign and delete
      await storage.reassignAndExcludeCategory('Gym', 'Others');

      final updatedTx = await storage.findTransactionById('tx1');
      expect(updatedTx?.category, 'Others');

      final categories = await storage.getCustomCategories();
      expect(categories.any((c) => c['name'] == 'Gym'), isFalse);
    });
  });
}
