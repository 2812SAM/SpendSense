/// SpendSense - Claude API service.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/transaction.dart';

class ClaudeService {
  ClaudeService._();
  static final ClaudeService instance = ClaudeService._();

  String _buildPrompt(String smsText, List<String> categories) {
    final catList = categories.join(', ') + ', ASK_USER';
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

  Future<MyTransaction?> categorise(String smsText, List<String> categories) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    try {
      final response = await _postToClaude(
        apiKey: apiKey,
        maxTokens: AppConstants.claudeMaxTokens,
        prompt: _buildPrompt(smsText, categories),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final rawText = _extractText(response.body);
      final parsedJson = _extractJson(rawText);
      return MyTransaction.fromClaudeResponse(parsedJson, smsText);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> understandVoiceNote(
    String voiceText,
    MyTransaction pending,
    List<String> categories,
  ) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return {
        'category': 'Others',
        'type': AppConstants.typeExpense,
        'note': voiceText,
      };
    }

    final catList = categories.join('|') + '|Loan';
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
      final response = await _postToClaude(
        apiKey: apiKey,
        maxTokens: 128,
        prompt: prompt,
      );

      if (response.statusCode != 200) {
        return {
          'category': 'Others',
          'type': AppConstants.typeExpense,
          'note': voiceText,
        };
      }

      final raw = _extractText(response.body);
      final parsed = _extractJson(raw);
      return {
        'category': parsed['category'] as String? ?? 'Others',
        'type': parsed['type'] as String? ?? AppConstants.typeExpense,
        'note': parsed['note'] as String? ?? voiceText,
      };
    } catch (_) {
      return {
        'category': 'Others',
        'type': AppConstants.typeExpense,
        'note': voiceText,
      };
    }
  }

  Future<bool> testApiKey(String apiKey) async {
    try {
      final response = await _postToClaude(
        apiKey: apiKey,
        maxTokens: 16,
        prompt: 'Return ONLY this JSON: {"ok": true}',
      );

      if (response.statusCode != 200) {
        return false;
      }

      final raw = _extractText(response.body);
      final parsed = _extractJson(raw);
      return parsed['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _postToClaude({
    required String apiKey,
    required int maxTokens,
    required String prompt,
  }) {
    return http.post(
      Uri.parse(AppConstants.claudeBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': AppConstants.claudeVersion,
      },
      body: jsonEncode({
        'model': AppConstants.claudeModel,
        'max_tokens': maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      }),
    );
  }

  String _extractText(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final content = body['content'] as List<dynamic>;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  Map<String, dynamic> _extractJson(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').trim();
    }
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefClaudeApiKey);
  }
}
