/// SpendSense - Google Sheets sync service.

import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/transaction.dart';
import '../services/secure_storage_service.dart';

class SheetsService {
  final http.Client _client;
  final SecureStorageService _secure;

  SheetsService({
    http.Client? client,
    SecureStorageService? secure,
  })  : _client = client ?? http.Client(),
        _secure = secure ?? SecureStorageService.instance;

  static final SheetsService instance = SheetsService(
    secure: SecureStorageService.instance,
  );

  bool debugForceFail = false;

  Future<bool> logMyTransaction(MyTransaction transaction) async {
    if (kDebugMode && debugForceFail) return false;
    final webhookUrl = await getSavedWebhookUrl();
    if (webhookUrl == null || webhookUrl.isEmpty) {
      return false;
    }

    try {
      final response = await _client
          .post(
            Uri.parse(webhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(transaction.toSheetJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> logBatch(List<MyTransaction> transactions) async {
    final failed = <String>[];

    for (final transaction in transactions) {
      final success = await logMyTransaction(transaction);
      if (!success) failed.add(transaction.id);
    }

    return failed;
  }

  Future<String?> getSavedWebhookUrl() async {
    final secureUrl = await _secure.readSecret(AppConstants.prefWebhookUrl);
    if (secureUrl != null && secureUrl.isNotEmpty) {
      return secureUrl;
    }

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(AppConstants.prefWebhookUrl);

    if (current != null && current.isNotEmpty) {
      return current;
    }

    final legacy = prefs.getString(AppConstants.legacyPrefWebhookUrl);
    if (legacy != null && legacy.isNotEmpty) {
      await prefs.setString(AppConstants.prefWebhookUrl, legacy);
      return legacy;
    }

    return null;
  }

  Future<void> saveWebhookUrl(String url) async {
    await _secure.saveSecret(AppConstants.prefWebhookUrl, url);
  }

  Future<bool> testWebhook(String url) async {
    try {
      final testPayload = {
        'date': 'TEST',
        'time': 'TEST',
        'amount': '1',
        'merchant': 'SpendSense Test',
        'category': 'Others',
        'note': 'Webhook test - you can delete this row',
        'confidence': 'HIGH',
        'type': 'EXPENSE',
      };

      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(testPayload),
      );

      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['status'] == 'success';
    } catch (_) {
      return false;
    }
  }
}
