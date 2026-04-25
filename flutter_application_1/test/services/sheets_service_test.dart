import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsense/services/sheets_service.dart';
import 'package:spendsense/services/secure_storage_service.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/core/constants.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late SheetsService service;
  late MockHttpClient mockClient;
  late MockSecureStorageService mockSecure;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    mockSecure = MockSecureStorageService();
    service = SheetsService(client: mockClient, secure: mockSecure);

    // Stub secure storage to return the webhook URL
    when(() => mockSecure.readSecret(any())).thenAnswer((_) async => null);
    when(() => mockSecure.readSecret(AppConstants.prefWebhookUrl))
        .thenAnswer((_) async => 'https://mock.webhook.com');

    SharedPreferences.setMockInitialValues({
      AppConstants.prefWebhookUrl: 'https://mock.webhook.com',
    });
  });

  group('SheetsService - logMyTransaction', () {
    test('should return true on successful sync', () async {
      final tx = MyTransaction(
        id: '1',
        timestamp: DateTime.now(),
        amount: 100,
        merchant: 'Test',
        category: 'Others',
        confidence: 'HIGH',
        type: 'EXPENSE',
        note: '',
        rawSms: '',
      );

      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer((_) async =>
              http.Response(jsonEncode({'status': 'success'}), 200));

      final result = await service.logMyTransaction(tx);
      expect(result, isTrue);
    });

    test('should return false on server error', () async {
      final tx = MyTransaction(
        id: '1',
        timestamp: DateTime.now(),
        amount: 100,
        merchant: 'Test',
        category: 'Others',
        confidence: 'HIGH',
        type: 'EXPENSE',
        note: '',
        rawSms: '',
      );

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Error', 500));

      final result = await service.logMyTransaction(tx);
      expect(result, isFalse);
    });
  });

  group('SheetsService - testWebhook', () {
    test('should return true when webhook responds success', () async {
      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer((_) async =>
              http.Response(jsonEncode({'status': 'success'}), 200));

      final result = await service.testWebhook('https://test.com');
      expect(result, isTrue);
    });
  });
}
