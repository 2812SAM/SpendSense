import 'package:flutter_test/flutter_test.dart';
import 'package:spendsense/services/local_parser_service.dart';

void main() {
  final parser = LocalParserService.instance;

  group('LocalParserService - Bank Specific Regex', () {
    test('HDFC - Should parse spent alert', () {
      const sms =
          'Alert: You\'ve spent Rs. 500.00 at Zomato on 2024-04-19. Transaction ID: 12345.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.merchant, 'Zomato');
      expect(result.category, 'Food');
    });

    test('ICICI - Should parse debited alert', () {
      const sms =
          'Dear Customer, your Acct XX123 is debited for INR 1,250.00 on 19-Apr-24. Info: VPS*Swiggy.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 1250.0);
      expect(result.merchant, 'Swiggy');
      expect(result.category, 'Food');
    });

    test('SBI - Should parse UPI to merchant', () {
      const sms =
          'Transaction of Rs. 200.00 on SBI UPI with Ref No 1234567890 to Amazon.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 200.0);
      expect(result.merchant, 'Amazon');
      expect(result.category, 'Shopping');
    });

    test('Axis - Should parse UPI P2M debited', () {
      const sms =
          'Axis Bank: INR 350.00 debited from Acct XX999 on 19/04/24 for UPI/P2M/Uber/12345.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 350.0);
      expect(result.merchant, 'Uber');
      expect(result.category, 'Transport');
    });
  });

  group('LocalParserService - Generic Patterns', () {
    test('Generic - Spent at store', () {
      const sms = 'Spent Rs 150 at Local Store.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 150.0);
      expect(result.merchant, 'Local Store');
    });

    test('Generic - Paid to person', () {
      const sms = 'Paid INR 2000 to John Doe for rent.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 2000.0);
      expect(result.merchant, 'John Doe');
    });
  });

  group('LocalParserService - Negative Filtering (Exclusions)', () {
    test('Income - Should ignore credited messages', () {
      const sms =
          'Rs 500.00 credited to your account XX123. Total balance is Rs 10,000.';
      final result = parser.parse(sms);
      expect(result, isNull);
    });

    test('Refund - Should ignore received messages', () {
      const sms = 'Amount of INR 150.00 received from Zomato as refund.';
      final result = parser.parse(sms);
      expect(result, isNull);
    });

    test('OTP - Should ignore bank security alerts', () {
      const sms =
          '123456 is your OTP for transaction of Rs 500 at Amazon. Do not share.';
      final result = parser.parse(sms);
      expect(result, isNull);
    });
  });

  group('LocalParserService - Edge Cases', () {
    test('Comma handling in amounts', () {
      const sms = 'Debited INR 1,25,000.00 to HDFC Home Loan.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 125000.0);
    });

    test('Noise cleaning in merchant names', () {
      const sms = 'Paid Rs. 49 to Store X/REF12345/Mumbai.';
      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.merchant, 'Store X');
    });
  });
}
