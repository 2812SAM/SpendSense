import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spendsense/services/secure_storage_service.dart';
import 'package:spendsense/core/constants.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late SecureStorageService service;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    service = SecureStorageService(storage: mockSecureStorage);

    // Stubbing write and read
    when(() => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => {});
  });

  test(
      'migrateFromPrefs should move data from SharedPreferences to SecureStorage',
      () async {
    const testApiKey = 'sk-ant-test-key';
    const testWebhook = 'https://test.webhook.com';

    SharedPreferences.setMockInitialValues({
      AppConstants.prefClaudeApiKey: testApiKey,
      AppConstants.prefWebhookUrl: testWebhook,
    });

    await service.migrateFromPrefs();

    // Verify it was written to secure storage
    verify(() => mockSecureStorage.write(
          key: AppConstants.prefClaudeApiKey,
          value: testApiKey,
        )).called(1);
    verify(() => mockSecureStorage.write(
          key: AppConstants.prefWebhookUrl,
          value: testWebhook,
        )).called(1);

    // Verify it was removed from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.prefClaudeApiKey), isNull);
    expect(prefs.getString(AppConstants.prefWebhookUrl), isNull);
  });
}
