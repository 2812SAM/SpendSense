import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsense/state/app_state.dart';
import 'package:spendsense/services/sms_service.dart';
import 'package:spendsense/services/claude_service.dart';
import 'package:spendsense/services/local_storage_service.dart';
import 'package:spendsense/services/sheets_service.dart';
import 'package:spendsense/services/notification_service.dart';
import 'package:spendsense/services/voice_service.dart';
import 'package:spendsense/services/digest_scheduler.dart';
import 'package:spendsense/services/local_parser_service.dart';
import 'package:spendsense/services/secure_storage_service.dart';

class MockSmsService extends Mock implements SmsService {}

class MockClaudeService extends Mock implements ClaudeService {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockSheetsService extends Mock implements SheetsService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockVoiceService extends Mock implements VoiceService {}

class MockDigestScheduler extends Mock implements DigestScheduler {}

class MockLocalParserService extends Mock implements LocalParserService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late AppState appState;

  setUp(() {
    appState = AppState(
      sms: MockSmsService(),
      local: MockLocalStorageService(),
      notif: MockNotificationService(),
      voice: MockVoiceService(),
      digest: MockDigestScheduler(),
      secure: MockSecureStorageService(),
    );
  });

  group('Deduplication Fingerprinting (Strict Raw Body)', () {
    test('identical SMS and sender should produce identical fingerprints', () {
      const sms = 'Rs 100 spent at Starbucks. Ref: 12345';
      const sender = 'HDFCBK';

      final f1 = appState.generateFingerprint(sms, sender);
      final f2 = appState.generateFingerprint(sms, sender);

      expect(f1, equals(f2));
    });

    test('SMS with different Ref IDs should produce different fingerprints',
        () {
      const sms1 = 'Rs 100 spent at Starbucks. Ref: 12345';
      const sms2 = 'Rs 100 spent at Starbucks. Ref: 12346';
      const sender = 'HDFCBK';

      final f1 = appState.generateFingerprint(sms1, sender);
      final f2 = appState.generateFingerprint(sms2, sender);

      expect(f1, isNot(equals(f2)));
    });

    test(
        'Same SMS from different senders should produce different fingerprints',
        () {
      const sms = 'Rs 100 spent at Starbucks. Ref: 12345';
      const sender1 = 'HDFCBK';
      const sender2 = 'ICICIB';

      final f1 = appState.generateFingerprint(sms, sender1);
      final f2 = appState.generateFingerprint(sms, sender2);

      expect(f1, isNot(equals(f2)));
    });

    test('Fingerprint should be stable across time (no time window)', () async {
      const sms = 'Rs 100 spent at Starbucks. Ref: 12345';
      const sender = 'HDFCBK';

      final f1 = appState.generateFingerprint(sms, sender);

      // Simulate delay
      await Future.delayed(const Duration(milliseconds: 100));

      final f2 = appState.generateFingerprint(sms, sender);

      expect(f1, equals(f2));
    });
  });
}
