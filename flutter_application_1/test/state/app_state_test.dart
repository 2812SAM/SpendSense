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
  late MockSheetsService mockSheets;

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
    mockSheets = MockSheetsService();

    appState = AppState(
      sms: mockSms,
      claude: mockClaude,
      local: mockLocal,
      notif: mockNotif,
      localParser: mockParser,
      secure: mockSecure,
      digest: mockDigest,
      sheets: mockSheets,
    );

    // Common Void Future Stubs
    when(() => mockLocal.upsertTransaction(any(),
        needsUserInput: any(named: 'needsUserInput'),
        sender: any(named: 'sender'),
        syncStatus: any(named: 'syncStatus'),
        lastError: any(named: 'lastError'),
        fingerprint: any(named: 'fingerprint'))).thenAnswer((_) async => {});
    when(() => mockNotif.showTransactionPopup(any())).thenAnswer((_) async => {});
    when(() => mockNotif.dismissTransactionNotification()).thenAnswer((_) async => {});
    when(() => mockNotif.dismissDigestNotification()).thenAnswer((_) async => {});
    when(() => mockLocal.markConfirmed(any(),
        category: any(named: 'category'),
        type: any(named: 'type'),
        note: any(named: 'note'))).thenAnswer((_) async => {});
    when(() => mockLocal.markSynced(any())).thenAnswer((_) async => {});
    when(() => mockLocal.markSyncFailed(any(), any())).thenAnswer((_) async => {});
    when(() => mockLocal.saveMerchantMemory(any(), any(), any(),
        isDynamic: any(named: 'isDynamic'))).thenAnswer((_) async => {});
    when(() => mockDigest.sync(any())).thenAnswer((_) async => {});
    
    // Common Value Future Stubs
    when(() => mockLocal.findByFingerprint(any())).thenAnswer((_) async => null);
    when(() => mockLocal.lookupMerchant(any())).thenAnswer((_) async => null);
    when(() => mockSecure.readSecret(any())).thenAnswer((_) async => null);
    when(() => mockLocal.getPending()).thenAnswer((_) async => []);
    when(() => mockLocal.getConfirmedPendingSync()).thenAnswer((_) async => []);
    when(() => mockSheets.logMyTransaction(any())).thenAnswer((_) async => true);
    when(() => mockClaude.categorise(any(), any())).thenAnswer((_) async => null);
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

  group('AppState - Classification Waterfall & Deduplication', () {
    const sms = 'Alert: You\'ve spent Rs. 100.00 at Starbucks on 2026-04-20.';
    const sender = 'AD-HDFCBK';

    test('should deduplicate identical SMS instantly', () async {
      // Setup: First time it's new
      when(() => mockLocal.findByFingerprint(any())).thenAnswer((_) async => null);
      when(() => mockParser.parse(any())).thenReturn(null);
      when(() => mockLocal.lookupMerchant(any())).thenAnswer((_) async => null);
      when(() => mockSecure.readSecret(any())).thenAnswer((_) async => null);
      when(() => mockLocal.upsertTransaction(any(), 
        needsUserInput: any(named: 'needsUserInput'),
        sender: any(named: 'sender'),
        syncStatus: any(named: 'syncStatus'),
        lastError: any(named: 'lastError'),
        fingerprint: any(named: 'fingerprint'),
      )).thenAnswer((_) async => {});
      when(() => mockNotif.showTransactionPopup(any())).thenAnswer((_) async => {});
      when(() => mockLocal.getPending()).thenAnswer((_) async => []);
      when(() => mockDigest.sync(any())).thenAnswer((_) async => {});

      // Act: Receive first time
      await appState.onPaymentSmsReceived(sms, sender);
      
      // Setup: Second time, findByFingerprint returns an existing record
      final mockTx = MyTransaction(
        id: '123', timestamp: DateTime.now(), amount: 100, merchant: 'Starbucks',
        category: 'Food', confidence: 'HIGH', type: 'EXPENSE', note: '', rawSms: sms,
      );
      when(() => mockLocal.findByFingerprint(any())).thenAnswer((_) async => mockTx);

      // Act: Receive second time
      await appState.onPaymentSmsReceived(sms, sender);

      // Assert: Upsert and Notification should only have been called ONCE (from first attempt)
      verify(() => mockLocal.upsertTransaction(any(), 
        needsUserInput: any(named: 'needsUserInput'),
        sender: any(named: 'sender'),
        syncStatus: any(named: 'syncStatus'),
        lastError: any(named: 'lastError'),
        fingerprint: any(named: 'fingerprint'),
      )).called(1);
      verify(() => mockNotif.showTransactionPopup(any())).called(1);
    });

    test('Path 1: Local Parser success should skip memory and AI', () async {
      when(() => mockLocal.findByFingerprint(any())).thenAnswer((_) async => null);
      
      // Mock local parser success
      final localResult = LocalParserResult(
        amount: 100, merchant: 'Starbucks', category: 'Food',
      );
      when(() => mockParser.parse(sms)).thenReturn(localResult);
      
      when(() => mockLocal.getPending()).thenAnswer((_) async => []);

      await appState.onPaymentSmsReceived(sms, sender);

      // Verify Path 1 taken
      verify(() => mockParser.parse(sms)).called(1);
      verify(() => mockLocal.upsertTransaction(any(), 
        needsUserInput: false, 
        sender: sender, 
        syncStatus: any(named: 'syncStatus'),
        lastError: any(named: 'lastError'),
        fingerprint: any(named: 'fingerprint'))).called(1);
      verifyNever(() => mockLocal.lookupMerchant(any()));
      verifyNever(() => mockClaude.categorise(any(), any()));
    });
  });

  test('confirmCategory should update local storage and trigger sync', () async {
    final tx = MyTransaction(
      id: 'tx_1', timestamp: DateTime.now(), amount: 100, merchant: 'Cafe',
      category: 'ASK_USER', confidence: 'LOW', type: 'EXPENSE', note: '', rawSms: '',
    );

    when(() => mockLocal.markConfirmed(any(), category: any(named: 'category'), type: any(named: 'type'), note: any(named: 'note')))
        .thenAnswer((_) async => {});
    when(() => mockLocal.saveMerchantMemory(any(), any(), any(), isDynamic: any(named: 'isDynamic')))
        .thenAnswer((_) async => {});
    when(() => mockSheets.logMyTransaction(any())).thenAnswer((_) async => true);
    when(() => mockLocal.markSynced(any())).thenAnswer((_) async => {});
    when(() => mockLocal.getPending()).thenAnswer((_) async => []);
    when(() => mockDigest.sync(any())).thenAnswer((_) async => {});

    await appState.confirmCategory(tx, 'Food', isDynamic: false);

    verify(() => mockLocal.markConfirmed(tx.id, category: 'Food', type: AppConstants.typeExpense, note: '')).called(1);
    verify(() => mockLocal.saveMerchantMemory('Cafe', 'Food', AppConstants.typeExpense, isDynamic: false)).called(1);
    verify(() => mockSheets.logMyTransaction(any())).called(1);
  });
}
