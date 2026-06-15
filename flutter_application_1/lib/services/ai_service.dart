import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/transaction.dart';
import 'ai/ai_provider.dart';
import 'ai/claude_provider.dart';
import 'ai/gemini_provider.dart';
import 'secure_storage_service.dart';

/// SpendSense - AI Service (Provider Manager).
/// Unified entry point for all AI-related tasks.
class AiService {
  final SecureStorageService _secure;
  final Map<String, AiProvider> _providers = {
    'claude': ClaudeProvider(),
    'gemini': GeminiProvider(),
  };

  AiService({SecureStorageService? secure})
      : _secure = secure ?? SecureStorageService.instance;

  static final AiService instance = AiService();

  /// Categorises a raw SMS message using the active provider.
  Future<MyTransaction?> categorise(
      String smsText, List<String> categories) async {
    final providerKey = await _getProviderKey();
    final apiKey = await _getApiKey(providerKey);

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint(
          'SpendSense AI: Skipping AI - No API key found for $providerKey.');
      return null;
    }

    final provider = _providers[providerKey] ?? _providers['claude']!;
    return await provider.categorise(smsText, categories, apiKey);
  }

  /// Interprets a voice note using the active provider.
  Future<Map<String, String>> understandVoiceNote(
    String voiceText,
    MyTransaction pending,
    List<String> categories,
  ) async {
    final providerKey = await _getProviderKey();
    final apiKey = await _getApiKey(providerKey);

    if (apiKey == null || apiKey.isEmpty) {
      return {
        'category': 'Others',
        'type': AppConstants.typeExpense,
        'note': voiceText,
      };
    }

    final provider = _providers[providerKey] ?? _providers['claude']!;
    return await provider.understandVoiceNote(
        voiceText, pending, categories, apiKey);
  }

  /// Tests the API key for a specific provider.
  Future<bool> testApiKey(String providerKey, String apiKey) async {
    final provider = _providers[providerKey];
    if (provider == null) return false;
    return await provider.testApiKey(apiKey);
  }

  Future<String> _getProviderKey() async {
    // Default to Claude for backward compatibility
    return await _secure.readSecret(AppConstants.prefAiProvider) ?? 'claude';
  }

  Future<String?> _getApiKey(String providerKey) async {
    if (providerKey == 'gemini') {
      return await _secure.readSecret(AppConstants.prefGeminiApiKey);
    }
    // Default to Claude key
    return await _secure.readSecret(AppConstants.prefClaudeApiKey);
  }
}
