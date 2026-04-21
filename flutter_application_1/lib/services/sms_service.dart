/// SpendSense - SMS service.
/// Foreground SMS gets processed immediately.
/// Background SMS is queued and drained on the next app launch.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

import '../core/constants.dart';

typedef OnPaymentSmsReceived = Future<void> Function(
    String smsBody, String sender);

class SmsService {
  SmsService._();
  static final SmsService instance = SmsService._();

  final Telephony _telephony = Telephony.instance;
  OnPaymentSmsReceived? _callback;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialise(OnPaymentSmsReceived onPayment) async {
    _callback = onPayment;

    final granted = await _telephony.requestSmsPermissions ?? false;
    if (!granted) {
      _isListening = false;
      return false;
    }

    _telephony.listenIncomingSms(
      onNewMessage: _onSms,
      onBackgroundMessage: _backgroundSmsHandler,
      listenInBackground: true,
    );

    _isListening = true;
    return true;
  }

  Future<void> processQueuedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final queue =
        prefs.getStringList(AppConstants.prefBackgroundSmsQueue) ?? [];
    if (queue.isEmpty) return;

    await prefs.remove(AppConstants.prefBackgroundSmsQueue);
    final failed = <String>[];

    for (final entry in queue) {
      try {
        final payload = jsonDecode(entry) as Map<String, dynamic>;
        final body = payload['body'] as String? ?? '';
        final sender = payload['sender'] as String? ?? '';

        if (!_isPaymentSms(body) || _callback == null) continue;
        await _callback!.call(body, sender);
      } catch (_) {
        failed.add(entry);
      }
    }

    if (failed.isNotEmpty) {
      await prefs.setStringList(AppConstants.prefBackgroundSmsQueue, failed);
    }
  }

  void _onSms(SmsMessage message) {
    final body = message.body ?? '';
    final sender = message.address ?? '';

    if (_isPaymentSms(body) && _callback != null) {
      _callback!.call(body, sender);
    }
  }

  bool _isPaymentSms(String body) {
    final lower = body.toLowerCase();
    return AppConstants.smsKeywords.any(lower.contains);
  }

  Future<List<SmsMessage>> fetchRecentPaymentSms({int limit = 50}) async {
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    return messages
        .where((m) => _isPaymentSms(m.body ?? ''))
        .take(limit)
        .toList();
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final body = message.body ?? '';
  final sender = message.address ?? '';

  if (!SmsService.instance._isPaymentSms(body)) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final queue = prefs.getStringList(AppConstants.prefBackgroundSmsQueue) ?? [];
  queue.add(jsonEncode({
    'body': body,
    'sender': sender,
    'received_at': DateTime.now().millisecondsSinceEpoch,
  }));
  await prefs.setStringList(AppConstants.prefBackgroundSmsQueue, queue);
}
