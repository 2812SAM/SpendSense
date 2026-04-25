import 'package:flutter_test/flutter_test.dart';
import 'package:spendsense/core/constants.dart';

void main() {
  group('AppConstants.isGenericId', () {
    test('should identify UPI generic IDs', () {
      expect(AppConstants.isGenericId('AX-SBIUPI'), isTrue);
      expect(AppConstants.isGenericId('PY-GAYUPI'), isTrue);
      expect(AppConstants.isGenericId('BX-HDFCBK'), isTrue);
    });

    test('should identify short bank codes', () {
      expect(AppConstants.isGenericId('HDFCBK'), isTrue);
      expect(AppConstants.isGenericId('ICICIB'), isTrue);
      expect(AppConstants.isGenericId('SBIUPI'), isTrue);
    });

    test('should NOT identify real merchant names', () {
      expect(AppConstants.isGenericId('Starbucks'), isFalse);
      expect(AppConstants.isGenericId('Amazon'), isFalse);
      expect(AppConstants.isGenericId('Zomato'), isFalse);
      expect(AppConstants.isGenericId('Uber'), isFalse);
      expect(AppConstants.isGenericId('Blinkit'), isFalse);
    });

    test('should be case sensitive (Bank IDs are typically CAPS)', () {
      expect(AppConstants.isGenericId('AX-SBIUPI'), isTrue);
      expect(AppConstants.isGenericId('ax-sbiupi'), isFalse);
      expect(AppConstants.isGenericId('Starbucks'), isFalse);
      expect(AppConstants.isGenericId('STARBUCKS'), isTrue); // This is acceptable as a fallback for all-caps strings
    });
  });
}
