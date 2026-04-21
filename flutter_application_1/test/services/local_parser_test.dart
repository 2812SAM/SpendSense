import 'package:flutter_test/flutter_test.dart';
import 'package:spendsense/services/local_parser_service.dart';

void main() {
  final parser = LocalParserService.instance;

  group('LocalParserService - HDFC Bank', () {
    test('should parse standard HDFC spend SMS', () {
      const sms = 'Alert: You\'ve spent Rs. 500.00 at Zomato on 2024-04-19. Transaction ID: 12345.';
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 500.00);
      expect(result.merchant, 'Zomato');
      expect(result.category, 'Food');
    });

    test('should parse Starbucks HDFC SMS (E2E Test Case)', () {
      const sms = 'Alert: You\'ve spent Rs. 100.00 at Starbucks on 2026-04-20.';
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 100.00);
      expect(result.merchant, 'Starbucks');
    });

    test('should parse HDFC SMS with comma in amount', () {
      const sms = 'Alert: You\'ve spent Rs. 1,250.50 at Amazon on 2024-04-19.';
      final result = parser.parse(sms);
      
      expect(result!.amount, 1250.50);
      expect(result.merchant, 'Amazon');
      expect(result.category, 'Shopping');
    });
  });

  group('LocalParserService - ICICI Bank', () {
    test('should parse standard ICICI debit SMS', () {
      const sms = 'Dear Customer, your Acct XX123 is debited for INR 1,250.00 on 19-Apr-24. Info: VPS*Swiggy.';
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 1250.00);
      expect(result.merchant, 'VPS*Swiggy');
      expect(result.category, 'Food');
    });
  });

  group('LocalParserService - SBI Bank', () {
    test('should parse SBI UPI transaction SMS', () {
      const sms = 'Transaction of Rs. 200.00 on SBI UPI with Ref No 1234567890 to Amazon.';
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 200.00);
      expect(result.merchant, 'Amazon');
      expect(result.category, 'Shopping');
    });

    test('should parse Swiggy SBI SMS (E2E Test Case)', () {
      const sms = 'Transaction of Rs. 250.00 on SBI UPI... to Swiggy.';
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 250.00);
      expect(result.merchant, 'Swiggy');
      expect(result.category, 'Food');
    });
  });

  group('LocalParserService - Axis Bank', () {
    test('should parse Axis Bank debit SMS', () {
      const sms = 'Axis Bank: INR 350.00 debited from Acct XX999 on 19/04/24 for UPI/P2M/Uber/12345.';
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 350.00);
      expect(result.merchant, 'Uber');
      expect(result.category, 'Travel');
    });
  });

  group('LocalParserService - Keyword Fallback', () {
    test('should categorize unknown merchant as Others', () {
      const sms = 'Alert: You\'ve spent Rs. 100.00 at Joe\'s Cafe on 2024-04-19.';
      final result = parser.parse(sms);
      
      expect(result!.merchant, 'Joe\'s Cafe');
      expect(result.category, 'Others');
    });

    test('should categorize Netflix as Entertainment', () {
      const sms = 'Alert: You\'ve spent Rs. 499.00 at Netflix on 2024-04-19.';
      final result = parser.parse(sms);
      
      expect(result!.category, 'Entertainment');
    });
  });

  group('LocalParserService - Failure Handling', () {
    test('should return null for non-payment SMS', () {
      const sms = 'Your OTP for logging into HDFC Bank is 123456. Do not share it.';
      final result = parser.parse(sms);
      
      expect(result, isNull);
    });
  });
}
