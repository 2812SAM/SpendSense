import 'package:flutter_test/flutter_test.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/services/insights/insights_service.dart';
import 'package:spendsense/services/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late InsightsService service;
  late MockLocalStorageService mockStorage;

  setUp(() {
    mockStorage = MockLocalStorageService();
    service = InsightsService(storage: mockStorage);
  });

  MyTransaction createTx(double amount, DateTime timestamp) {
    return MyTransaction(
      id: 'tx_${timestamp.millisecondsSinceEpoch}',
      amount: amount,
      timestamp: timestamp,
      merchant: 'Test',
      category: 'Food',
      confidence: 'HIGH',
      type: 'EXPENSE',
      isConfirmed: true,
    );
  }

  test('generateSnapshot returns Excellent when improvement > 15%', () async {
    final now = DateTime.now();
    final transactions = [
      createTx(100,
          now.subtract(const Duration(days: 1))), // Current week total: 100
      createTx(200,
          now.subtract(const Duration(days: 10))), // Previous week total: 200
    ];

    when(() => mockStorage.getRecentConfirmed(limit: 500))
        .thenAnswer((_) async => transactions);

    final snapshot = await service.generateSnapshot();

    expect(snapshot.healthStatus, 'Excellent');
    expect(snapshot.healthScore, 85);
  });

  test('generateSnapshot returns Improving when improvement is 10%', () async {
    final now = DateTime.now();
    final transactions = [
      createTx(90, now.subtract(const Duration(days: 1))), // Current: 90
      createTx(100, now.subtract(const Duration(days: 10))), // Prev: 100
    ];

    when(() => mockStorage.getRecentConfirmed(limit: 500))
        .thenAnswer((_) async => transactions);

    final snapshot = await service.generateSnapshot();

    expect(snapshot.healthStatus, 'Improving');
    expect(snapshot.healthScore, 75);
  });

  test('generateSnapshot returns empty snapshot when no transactions',
      () async {
    when(() => mockStorage.getRecentConfirmed(limit: 500))
        .thenAnswer((_) async => []);

    final snapshot = await service.generateSnapshot();

    expect(snapshot.isInitialised, false);
    expect(snapshot.healthScore, 0);
    expect(snapshot.topCategories, isEmpty);
  });
}
