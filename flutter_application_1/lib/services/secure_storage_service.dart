import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final SecureStorageService instance = SecureStorageService();

  Future<void> saveSecret(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readSecret(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: key);
  }

  /// Gets the database encryption key or generates one if it doesn't exist.
  Future<String> getDatabaseKey() async {
    String? key = await readSecret(AppConstants.dbEncryptionKey);
    if (key == null || key.isEmpty) {
      key = _generateRandomKey();
      await saveSecret(AppConstants.dbEncryptionKey, key);
    }
    return key;
  }

  String _generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Migrates secrets from SharedPreferences to SecureStorage if they exist.
  Future<void> migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Migrate API Key
    final apiKey = prefs.getString(AppConstants.prefClaudeApiKey);
    if (apiKey != null && apiKey.isNotEmpty) {
      await saveSecret(AppConstants.prefClaudeApiKey, apiKey);
      await prefs.remove(AppConstants.prefClaudeApiKey);
      // ignore: avoid_print
      print('SpendSense: Migrated Claude API Key to Secure Storage');
    }

    // Migrate Webhook URL
    final webhook = prefs.getString(AppConstants.prefWebhookUrl);
    if (webhook != null && webhook.isNotEmpty) {
      await saveSecret(AppConstants.prefWebhookUrl, webhook);
      await prefs.remove(AppConstants.prefWebhookUrl);
      // ignore: avoid_print
      print('SpendSense: Migrated Webhook URL to Secure Storage');
    }
  }
}
