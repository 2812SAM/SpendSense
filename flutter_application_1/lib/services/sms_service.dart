/// SpendSense - SMS service.
/// Foreground SMS gets processed immediately.
/// Background SMS is queued and drained on the next app launch.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

import '../core/constants.dart';
import '../models/transaction.dart';
import 'claude_service.dart';
import 'local_parser_service.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';
import 'secure_storage_service.dart';
import 'sms_orchestrator.dart';
import 'sync_service.dart';
import 'voice_service.dart';

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

        if (!isPaymentSms(body) || _callback == null) continue;
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

    if (isPaymentSms(body) && _callback != null) {
      _callback!.call(body, sender);
    }
  }

  static bool isPaymentSms(String body) {
    final lower = body.toLowerCase();
    return AppConstants.smsKeywords.any(lower.contains);
  }

  Future<List<SmsMessage>> fetchRecentPaymentSms({int limit = 50}) async {
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    return messages
        .where((m) => isPaymentSms(m.body ?? ''))
        .take(limit)
        .toList();
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundSmsHandler(SmsMessage message) async {
  debugPrint('SpendSense: Background Isolate Waking Up...');

  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final body = message.body ?? '';
    final sender = message.address ?? '';
    debugPrint('SpendSense: SMS Received from $sender');

    if (!SmsService.isPaymentSms(body)) {
      debugPrint('SpendSense: SMS ignored (not a payment message).');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // SPEND-013: Simple Mutex to prevent simultaneous DB/Prefs access
    final isProcessing = prefs.getBool('is_processing_sms') ?? false;
    if (isProcessing) {
      debugPrint('SpendSense: Background already busy. Queuing SMS for later.');
      final queue =
          prefs.getStringList(AppConstants.prefBackgroundSmsQueue) ?? [];
      queue.add(jsonEncode({
        'body': body,
        'sender': sender,
        'received_at': DateTime.now().millisecondsSinceEpoch,
      }));
      await prefs.setStringList(AppConstants.prefBackgroundSmsQueue, queue);
      return;
    }

    // Set Lock
    await prefs.setBool('is_processing_sms', true);

    try {
      debugPrint('SpendSense: Initializing headless services...');
      // 1. Initialize Headless Services
      final secureStorage = SecureStorageService.instance;
      final localStorage = LocalStorageService(isBackground: true);
      final notificationService = NotificationService.instance;
      final claudeService = ClaudeService.instance;
      final voiceService = VoiceService.instance;
      final localParser = LocalParserService.instance;

      // 2. Open Secure Database
      debugPrint('SpendSense: Unlocking secure database in background...');
      await localStorage.database;
      debugPrint('SpendSense: Database unlocked.');

      // Initialize notifications for transaction popups
      await notificationService.initialise();

      // 3. Fetch categories (Core + User Defined)
      final customCategories = await localStorage.getCustomCategories();
      final allCategories = [
        ...AppConstants.defaultCategories,
        ...customCategories
      ];

      // 4. Initialize Orchestrator with Background-Safe Sync
      final orchestrator = SmsOrchestrator(
        claude: claudeService,
        local: localStorage,
        notif: notificationService,
        localParser: localParser,
        secure: secureStorage,
        sync: _BackgroundNoOpSyncService(local: localStorage),
        voice: voiceService,
      );

      // 5. Run full waterfall logic
      debugPrint('SpendSense: Starting waterfall processing...');
      await orchestrator.processSms(body, sender, allCategories: allCategories);
      debugPrint('SpendSense: Background processing completed successfully.');

      // Also process any previously queued messages while we have the DB open
      await _processQueuedMessagesHeadless(orchestrator, allCategories);

    } finally {
      // Release Lock
      await prefs.setBool('is_processing_sms', false);
    }

  } catch (e, stack) {
    debugPrint('SpendSense CRITICAL: Background processing failed: $e');
    debugPrint(stack.toString());

    // Fallback: Queue for foreground processing if background fails
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(AppConstants.prefBackgroundSmsQueue) ?? [];
      queue.add(jsonEncode({
        'body': message.body,
        'sender': message.address,
        'received_at': DateTime.now().millisecondsSinceEpoch,
        'error': e.toString(),
      }));
      await prefs.setStringList(AppConstants.prefBackgroundSmsQueue, queue);
      debugPrint('SpendSense: SMS queued for foreground retry.');
    } catch (e2) {
      debugPrint('SpendSense: Fatal error during fallback queuing: $e2');
    }
  }
}

Future<void> _processQueuedMessagesHeadless(
    SmsOrchestrator orchestrator, List<String> allCategories) async {
  final prefs = await SharedPreferences.getInstance();
  final queue = prefs.getStringList(AppConstants.prefBackgroundSmsQueue) ?? [];
  if (queue.isEmpty) return;

  debugPrint('SpendSense: Processing ${queue.length} queued messages in background...');
  await prefs.remove(AppConstants.prefBackgroundSmsQueue);
  
  final failed = <String>[];

  for (final entry in queue) {
    try {
      final payload = jsonDecode(entry) as Map<String, dynamic>;
      final body = payload['body'] as String? ?? '';
      final sender = payload['sender'] as String? ?? '';

      if (!SmsService.isPaymentSms(body)) continue;
      await orchestrator.processSms(body, sender, allCategories: allCategories);
    } catch (e) {
      debugPrint('SpendSense: Headless retry failed: $e');
      failed.add(entry);
    }
  }

  if (failed.isNotEmpty) {
    await prefs.setStringList(AppConstants.prefBackgroundSmsQueue, failed);
  }
}

/// Specialized SyncService for background processing.
/// Prevents expensive network calls to Google Sheets to save battery and data.
class _BackgroundNoOpSyncService extends SyncService {
  _BackgroundNoOpSyncService({super.local});

  @override
  Future<bool> syncTransaction(MyTransaction transaction) async {
    // Return false to keep status as 'pending'.
    // The orchestrator will already have saved it to SQLite.
    return false;
  }

  @override
  Future<void> retryUnsyncedTransactions() async {
    // No-op to avoid background network activity.
  }
}
