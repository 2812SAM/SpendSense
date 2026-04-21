import 'package:flutter_test/flutter_test.dart';

import 'package:spendsense/models/transaction.dart';

void main() {
  test('manual review transactions require user input', () {
    final transaction = MyTransaction.manualReview(
      rawSms: 'INR 450 debited for transfer to Rahul',
      merchant: 'Rahul',
      amount: 450,
    );

    expect(transaction.requiresUserInput, isTrue);
    expect(transaction.isConfirmed, isFalse);
  });

  test('copyWith preserves existing values unless overridden', () {
    final original = MyTransaction.manualReview(
      rawSms: 'SMS',
      merchant: 'Zomato',
      amount: 250,
    );

    final updated = original.copyWith(
      category: 'Food',
      isConfirmed: true,
      isLogged: true,
    );

    expect(updated.merchant, 'Zomato');
    expect(updated.category, 'Food');
    expect(updated.isConfirmed, isTrue);
    expect(updated.isLogged, isTrue);
  });
}
