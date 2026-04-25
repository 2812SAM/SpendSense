import 'package:flutter_test/flutter_test.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/core/constants.dart';

void main() {
  group('MyTransaction Model', () {
    test('manualReview should create a low-confidence transaction', () {
      final tx = MyTransaction.manualReview(
        rawSms: 'Spent 500',
        merchant: 'Unknown',
        amount: 500,
      );

      expect(tx.requiresUserInput, isTrue);
      expect(tx.confidence, AppConstants.confidenceLow);
      expect(tx.category, 'ASK_USER');
    });

    test('toMap and fromMap should be symmetric', () {
      final original = MyTransaction(
        id: '123',
        timestamp: DateTime(2026, 4, 21, 10, 30),
        amount: 150.75,
        merchant: 'Cafe',
        category: 'Food',
        confidence: 'HIGH',
        type: 'EXPENSE',
        note: 'Tasty',
        rawSms: 'Sms Body',
        isLogged: true,
        isConfirmed: true,
      );

      final map = original.toMap();
      final fromMap = MyTransaction.fromMap(map);

      expect(fromMap.id, original.id);
      expect(fromMap.timestamp, original.timestamp);
      expect(fromMap.amount, original.amount);
      expect(fromMap.merchant, original.merchant);
      expect(fromMap.category, original.category);
      expect(fromMap.isLogged, isTrue);
      expect(fromMap.isConfirmed, isTrue);
    });

    test('toSheetJson should format columns correctly for Google Sheets', () {
      final tx = MyTransaction(
        id: '1',
        timestamp: DateTime(2026, 4, 21, 15, 45),
        amount: 1000,
        merchant: 'Rent Manager',
        category: 'Rent',
        confidence: 'HIGH',
        type: 'EXPENSE',
        note: 'Monthly Rent',
        rawSms: '',
      );

      final json = tx.toSheetJson();

      expect(json['date'], '2026-04-21');
      expect(json['time'], '15:45');
      expect(json['amount'], '1000.00');
      expect(json['category'], 'Rent');
    });

    test('fromClaudeResponse should parse dynamic AI output', () {
      final claudeJson = {
        'amount': 250.50,
        'merchant': 'Zomato',
        'category': 'Food',
        'confidence': 'HIGH',
        'type': 'EXPENSE',
        'note': 'Dinner'
      };
      
      final tx = MyTransaction.fromClaudeResponse(claudeJson, 'Raw SMS Text');

      expect(tx.amount, 250.50);
      expect(tx.merchant, 'Zomato');
      expect(tx.isConfirmed, isFalse); // Claude responses need user confirmation or high-confidence check in AppState
    });

    test('copyWith should allow partial updates', () {
      final tx = MyTransaction(
        id: '1', timestamp: DateTime.now(), amount: 10, merchant: 'M',
        category: 'Others', confidence: 'LOW', type: 'EXPENSE', note: '', rawSms: '',
      );

      final updated = tx.copyWith(category: 'Food', isConfirmed: true);

      expect(updated.category, 'Food');
      expect(updated.isConfirmed, isTrue);
      expect(updated.merchant, tx.merchant); // Should stay the same
    });
  });
}
