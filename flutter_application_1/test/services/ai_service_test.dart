import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:spendsense/services/ai_service.dart';
import 'package:spendsense/services/secure_storage_service.dart';
import 'package:spendsense/core/constants.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AiService service;
  late MockSecureStorageService mockSecure;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockSecure = MockSecureStorageService();
    service = AiService(secure: mockSecure);

    // Default to Claude for tests
    when(() => mockSecure.readSecret(AppConstants.prefAiProvider))
        .thenAnswer((_) async => 'claude');
    when(() => mockSecure.readSecret(AppConstants.prefClaudeApiKey))
        .thenAnswer((_) async => 'sk-ant-test-key');
  });

  group('AiService - routing', () {
    test('should return null if no API key is found', () async {
      when(() => mockSecure.readSecret(AppConstants.prefClaudeApiKey))
          .thenAnswer((_) async => null);

      final result = await service.categorise('Test SMS', ['Food']);
      expect(result, isNull);
    });
  });
}
