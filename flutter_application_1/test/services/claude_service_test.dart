import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsense/services/claude_service.dart';
import 'package:spendsense/core/constants.dart';
import 'package:spendsense/models/transaction.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late ClaudeService service;
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    service = ClaudeService(client: mockClient);

    // Set mock API key in SharedPreferences
    SharedPreferences.setMockInitialValues({
      AppConstants.prefClaudeApiKey: 'sk-ant-test-key',
    });
  });

  group('ClaudeService - categorise', () {
    test('should return MyTransaction on successful 200 response', () async {
      final mockResponse = {
        'content': [
          {
            'text': jsonEncode({
              'amount': 500,
              'merchant': 'Amazon',
              'category': 'Shopping',
              'confidence': 'HIGH',
              'type': 'EXPENSE',
              'note': 'Test note'
            })
          }
        ]
      };

      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode(mockResponse), 200));

      final result = await service.categorise('Test SMS', ['Shopping', 'Food']);

      expect(result, isNotNull);
      expect(result!.merchant, 'Amazon');
      expect(result.amount, 500);
      expect(result.category, 'Shopping');
    });

    test('should return null on 500 response', () async {
      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer((_) async => http.Response('Internal Server Error', 500));

      final result = await service.categorise('Test SMS', ['Shopping']);

      expect(result, isNull);
    });
  });

  group('ClaudeService - understandVoiceNote', () {
    test('should return mapped fields on success', () async {
      final mockResponse = {
        'content': [
          {
            'text': jsonEncode({
              'category': 'Food',
              'type': 'EXPENSE',
              'note': 'Lunch at Office'
            })
          }
        ]
      };

      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode(mockResponse), 200));

      final pending = MyTransaction(
        id: '1',
        timestamp: DateTime.now(),
        amount: 100,
        merchant: 'Cafe',
        category: 'Others',
        confidence: 'LOW',
        type: 'EXPENSE',
        note: '',
        rawSms: '',
      );

      final result = await service
          .understandVoiceNote('I ate lunch', pending, ['Food', 'Health']);

      expect(result['category'], 'Food');
      expect(result['note'], 'Lunch at Office');
    });
  });
}
