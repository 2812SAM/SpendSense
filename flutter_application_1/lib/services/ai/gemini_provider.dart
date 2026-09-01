import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../models/transaction.dart';
import 'ai_provider.dart';

/// SpendSense - Gemini AI Provider implementation.
class GeminiProvider implements AiProvider {
  final http.Client _client = http.Client();

  @override
  String get name => 'Gemini';

  @override
  Future<bool> testApiKey(String apiKey) async {
    try {
      final response = await _postToGemini(
        apiKey: apiKey,
        prompt: 'Return ONLY this JSON: {"ok": true}',
      );

      if (response.statusCode != 200) return false;

      final raw = _extractText(response.body);
      final parsed = _extractJson(raw);
      return parsed['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<MyTransaction?> categorise(
    String smsText,
    List<String> categories,
    String apiKey,
  ) async {
    debugPrint('SpendSense AI: Categorising SMS with Gemini...');

    try {
      final response = await _postToGemini(
        apiKey: apiKey,
        prompt: _buildCategorisePrompt(smsText, categories),
      );

      if (response.statusCode != 200) {
        debugPrint(
            'SpendSense AI Error: Gemini HTTP ${response.statusCode} - ${response.body}');
        return null;
      }

      final rawText = _extractText(response.body);
      final parsedJson = _extractJson(rawText);

      debugPrint(
          'SpendSense AI: Gemini successfully categorised as ${parsedJson['category']}.');

      return MyTransaction.fromClaudeResponse(parsedJson, smsText);
    } catch (e) {
      debugPrint('SpendSense AI Exception (Gemini): $e');
      return null;
    }
  }

  @override
  Future<Map<String, String>> understandVoiceNote(
    String voiceText,
    MyTransaction pending,
    List<String> categories,
    String apiKey,
  ) async {
    final catList = '${categories.join('|')}|Loan';
    final prompt = '''
A user made a payment of ₹${pending.amount} to "${pending.merchant}".
The user said: "$voiceText"

Based on this, return ONLY a JSON:
{
  "category": "<$catList>",
  "type": "<EXPENSE|LOAN>",
  "note": "<concise note summarising what user said, max 50 chars>"
}
''';

    try {
      final response = await _postToGemini(
        apiKey: apiKey,
        prompt: prompt,
      );

      if (response.statusCode != 200) return _voiceFallback(voiceText);

      final raw = _extractText(response.body);
      final parsed = _extractJson(raw);
      return {
        'category': parsed['category'] as String? ?? 'Others',
        'type': parsed['type'] as String? ?? AppConstants.typeExpense,
        'note': parsed['note'] as String? ?? voiceText,
      };
    } catch (_) {
      return _voiceFallback(voiceText);
    }
  }

  String _buildCategorisePrompt(String smsText, List<String> categories) {
    final catList = '${categories.join(', ')}, ASK_USER';
    return '''
You are an expense categoriser for Indian UPI and bank transactions.
Read the SMS below and return ONLY a valid JSON object. No explanation. No markdown. No code blocks.

SMS: "$smsText"

Return exactly this JSON structure:
{
  "amount": <number, INR amount as integer or decimal>,
  "merchant": "<merchant name or UPI handle or person name>",
  "category": "<one of: $catList>",
  "confidence": "<HIGH or LOW>",
  "type": "<EXPENSE or LOAN>",
  "note": "<brief auto-note, empty string if nothing relevant>"
}

Rules:
- confidence = HIGH if merchant is a well-known Indian brand, app, chain, or service
- confidence = LOW if merchant is a personal name, unknown shop, or ambiguous
- type = LOAN if the text suggests giving money to a person
- type = EXPENSE for all purchases from merchants/apps
- If confidence is LOW, set category to "ASK_USER"
- If type is LOAN, set category to "Loan"
- For person-to-person payments with small amounts at social hours, prefer EXPENSE with ASK_USER
- amount should be a plain number with no currency symbol
''';
  }

  Future<http.Response> _postToGemini({
    required String apiKey,
    required String prompt,
  }) {
    // Using gemini-1.5-flash for speed and cost efficiency
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    return _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      }),
    );
  }

  String _extractText(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>;
    final content = candidates.first['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;
    return parts.first['text'] as String;
  }

  Map<String, dynamic> _extractJson(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').trim();
    }
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  Map<String, String> _voiceFallback(String voiceText) {
    return {
      'category': 'Others',
      'type': AppConstants.typeExpense,
      'note': voiceText,
    };
  }
}
