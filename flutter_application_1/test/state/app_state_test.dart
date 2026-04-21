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
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/core/constants.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState appState;
  late MockSmsService mockSms;
  late MockClaudeService mockClaude;
  late MockLocalStorageService mockLocal;
  late MockNotificationService mockNotif;
  late MockLocalParserService mockParser;
  late MockSecureStorageService mockSecure;
  late MockDigestScheduler mockDigest;

  setUpAll(() {
    registerFallbackValue(MyTransaction(
      id: '', timestamp: DateTime.now(), amount: 0, merchant: '', category: '',
      confidence: '', type: '', note: '', rawSms: '',
    ));
  });

  setUp(() {
    mockSms = MockSmsService();
    mockClaude = MockClaudeService();
    mockLocal = MockLocalStorageService();
    mockNotif = MockNotificationService();
    mockParser = MockLocalParserService();
    mockSecure = MockSecureStorageService();
    mockDigest = MockDigestScheduler();

    appState = AppState(
      sms: mockSms,
      claude: mockClaude,
      local: mockLocal,
      notif: mockNotif,
      localParser: mockParser,
      secure: mockSecure,
      digest: mockDigest,
    );
  });

  test('Unknown SMS with no Claude key should trigger Manual Review flow', () async {
    const smsBody = 'Unknown message about spending 500';
    const sender = '123456';

    // 0. Mock fingerprint check
    when(() => mockLocal.findByFingerprint(any())).thenAnswer((_) async => null);

    // 1. Mock Local Parser failure
    when(() => mockParser.parse(smsBody)).thenReturn(null);

    // 2. Mock Merchant Memory failure
    when(() => mockLocal.lookupMerchant(any())).thenAnswer((_) async => null);

    // 3. Mock Secure Storage (No Claude Key)
    when(() => mockSecure.readSecret(AppConstants.prefClaudeApiKey)).thenAnswer((_) async => null);

    // 4. Mock Local Storage upsert
    when(() => mockLocal.upsertTransaction(
          any(),
          needsUserInput: any(named: 'needsUserInput'),
          sender: any(named: 'sender'),
          syncStatus: any(named: 'syncStatus'),
          lastError: any(named: 'lastError'),
          fingerprint: any(named: 'fingerprint'),
        )).thenAnswer((_) async => {});

    // 5. Mock Notification
    when(() => mockNotif.showTransactionPopup(any())).thenAnswer((_) async => {});
    
    // 6. Mock load pending & Digest
    when(() => mockLocal.getPending()).thenAnswer((_) async => []);
    when(() => mockDigest.sync(any())).thenAnswer((_) async => {});

    // ACT
    await appState.onPaymentSmsReceived(smsBody, sender);

    // ASSERT
    expect(appState.txState, TxState.awaitingUser);
    verify(() => mockNotif.showTransactionPopup(any())).called(1);
    verify(() => mockLocal.upsertTransaction(
          any(),
          needsUserInput: true,
          sender: sender,
          lastError: any(named: 'lastError'),
          fingerprint: any(named: 'fingerprint'),
        )).called(1);
  });
}
