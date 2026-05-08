import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/ai_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/local_parser_service.dart';
import '../services/sync_service.dart';
import '../services/voice_service.dart';
import '../services/contact_service.dart';
import '../core/constants.dart';

enum SmsProcessingResult {
  deduplicated,
  autoLogged,
  awaitingUser,
  error,
}

class SmsOrchestrator {
  final AiService _ai;
  final LocalStorageService _local;
  final NotificationService _notif;
  final LocalParserService _localParser;
  final SyncService _sync;
  final VoiceService _voice;
  final ContactService _contacts;

  SmsOrchestrator({
    AiService? ai,
    LocalStorageService? local,
    NotificationService? notif,
    LocalParserService? localParser,
    SyncService? sync,
    VoiceService? voice,
    ContactService? contacts,
  })  : _ai = ai ?? AiService.instance,
        _local = local ?? LocalStorageService(isBackground: false),
        _notif = notif ?? NotificationService.instance,
        _localParser = localParser ?? LocalParserService.instance,
        _sync = sync ?? SyncService.instance,
        _voice = voice ?? VoiceService.instance,
        _contacts = contacts ?? ContactService.instance;

  static final SmsOrchestrator instance = SmsOrchestrator();

  Future<SmsProcessingResult> processSms(
    String smsBody,
    String sender, {
    required List<String> allCategories,
    Function(MyTransaction)? onTransactionFound,
  }) async {
    // 0. Resolve Contact Name
    final resolvedSenderName = await _contacts.resolveName(sender);
    final effectiveSender = resolvedSenderName ?? sender;

    // 0.1 Deduplication check
    final fingerprint = generateFingerprint(smsBody, sender);
    final existing = await _local.findByFingerprint(fingerprint);
    if (existing != null) {
      return SmsProcessingResult.deduplicated;
    }

    // 1. Try Local Parser (Regex)
    final localResult = _localParser.parse(smsBody);
    if (localResult != null) {
      final transaction = MyTransaction(
        id: _generateId(),
        timestamp: DateTime.now(),
        amount: localResult.amount,
        merchant: localResult.merchant,
        category: localResult.category,
        confidence: localResult.confidence,
        type: localResult.type,
        note: 'Parsed locally',
        rawSms: smsBody,
        isConfirmed: true,
      );

      await _local.upsertTransaction(
        transaction,
        needsUserInput: false,
        sender: sender,
        syncStatus: AppConstants.syncPending,
        fingerprint: fingerprint,
      );
      onTransactionFound?.call(transaction);
      await _sync.syncTransaction(transaction);
      return SmsProcessingResult.autoLogged;
    }

    // 2. Try Merchant Memory
    final merchantHint = _fallbackMerchantName(smsBody, sender);
    final memory = await _local.lookupMerchant(merchantHint);
    if (memory != null) {
      final quickTransaction = MyTransaction(
        id: _generateId(),
        timestamp: DateTime.now(),
        amount: _quickParseAmount(smsBody),
        merchant: _displayMerchant(merchantHint, memory.merchantKey),
        category: memory.category,
        confidence: AppConstants.confidenceHigh,
        type: memory.type,
        note: memory.isDynamic
            ? 'Pre-filled from memory'
            : 'Auto-categorised from memory',
        rawSms: smsBody,
        isConfirmed: !memory.isDynamic,
      );

      onTransactionFound?.call(quickTransaction);

      if (memory.isDynamic) {
        await _local.upsertTransaction(
          quickTransaction,
          needsUserInput: true,
          sender: sender,
          syncStatus: AppConstants.syncPending,
          fingerprint: fingerprint,
        );
        await _notif.showTransactionPopup(quickTransaction);
        return SmsProcessingResult.awaitingUser;
      } else {
        await _local.upsertTransaction(
          quickTransaction,
          needsUserInput: false,
          sender: sender,
          syncStatus: AppConstants.syncPending,
          fingerprint: fingerprint,
        );
        await _sync.syncTransaction(quickTransaction);
        return SmsProcessingResult.autoLogged;
      }
    }

    // 3. Try AI Engine
    final contextSms = 'From: $effectiveSender\nBody: $smsBody';
    final transaction = await _ai.categorise(contextSms, allCategories);

    if (transaction != null) {
      onTransactionFound?.call(transaction);

      if (transaction.confidence == AppConstants.confidenceHigh) {
        final confirmed = transaction.copyWith(isConfirmed: true);
        await _local.upsertTransaction(
          confirmed,
          needsUserInput: false,
          sender: sender,
          syncStatus: AppConstants.syncPending,
          fingerprint: fingerprint,
        );
        await _sync.syncTransaction(confirmed);
        return SmsProcessingResult.autoLogged;
      }

      await _local.upsertTransaction(
        transaction,
        needsUserInput: true,
        sender: sender,
        syncStatus: AppConstants.syncPending,
        fingerprint: fingerprint,
      );
      await _notif.showTransactionPopup(transaction);
      return SmsProcessingResult.awaitingUser;
    }

    // 4. Fallback to Manual Review
    final fallback = MyTransaction.manualReview(
      rawSms: smsBody,
      merchant: _fallbackMerchantName(smsBody, effectiveSender),
      amount: _quickParseAmount(smsBody),
    );

    onTransactionFound?.call(fallback);

    await _local.upsertTransaction(
      fallback,
      needsUserInput: true,
      sender: sender,
      syncStatus: AppConstants.syncPending,
      lastError: 'Local parsing and AI classification unavailable/failed',
      fingerprint: fingerprint,
    );
    await _notif.showTransactionPopup(fallback);
    return SmsProcessingResult.awaitingUser;
  }

  Future<void> confirmCategory(
    MyTransaction transaction,
    String category, {
    bool isDynamic = false,
  }) async {
    try {
      final resolvedType =
          category == 'Loan' ? AppConstants.typeLoan : transaction.type;
      final resolvedCategory = category == 'Loan' ? 'Loan' : category;

      final confirmed = transaction.copyWith(
        category: resolvedCategory,
        type: resolvedType,
        isConfirmed: true,
      );

      await _local.markConfirmed(
        transaction.id,
        category: resolvedCategory,
        type: resolvedType,
        note: confirmed.note,
      );
      await _local.saveMerchantMemory(
        transaction.merchant,
        resolvedCategory,
        resolvedType,
        isDynamic: isDynamic,
      );
      await _notif.dismissTransactionNotification(transaction.id);

      // SYNC: Non-blocking background call
      unawaited(_sync.syncTransaction(confirmed));
    } catch (e) {
      debugPrint('SpendSense Error: Failed to confirm category: $e');
      rethrow;
    }
  }

  Future<MyTransaction?> confirmWithVoice(
    MyTransaction transaction,
    List<String> allCategories,
    Function(bool) onListeningChange,
  ) async {
    onListeningChange(true);
    final voiceText = await _voice.listen();
    onListeningChange(false);

    if (voiceText == null || voiceText.isEmpty) return null;

    final understood =
        await _ai.understandVoiceNote(voiceText, transaction, allCategories);
    final category = understood['category'] ?? 'Others';
    final type = understood['type'] ?? AppConstants.typeExpense;
    final note = understood['note'] ?? voiceText;

    final confirmed = transaction.copyWith(
      category: category,
      type: type,
      note: note,
      isConfirmed: true,
    );

    await _local.markConfirmed(
      transaction.id,
      category: category,
      type: type,
      note: note,
    );
    await _local.saveMerchantMemory(confirmed.merchant, category, type);
    await _local.upsertTransaction(
      confirmed,
      needsUserInput: false,
      syncStatus: AppConstants.syncPending,
    );

    // SYNC: Non-blocking background call
    unawaited(_sync.syncTransaction(confirmed));

    return confirmed;
  }

  Future<void> confirmAll(
    List<MyTransaction> pendingTransactions,
    Map<String, String> categoryMap, {
    Map<String, bool>? dynamicMap,
  }) async {
    for (final transaction in pendingTransactions) {
      final category = categoryMap[transaction.id] ?? 'Others';
      final isDynamic = dynamicMap?[transaction.id] ?? false;

      // confirmCategory is now non-blocking for sync
      await confirmCategory(transaction, category, isDynamic: isDynamic);
    }
    await _notif.dismissDigestNotification();
  }

  String generateFingerprint(String sms, String sender) {
    final bytes = utf8.encode('$sender|$sms');
    return sha256.convert(bytes).toString();
  }

  String _generateId() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 1000}';
  }

  String _extractMerchantHint(String sms) {
    final match = RegExp(
      r'(?:to|paid|transferred to)\s+([A-Z][A-Z\s]{2,})',
      caseSensitive: false,
    ).firstMatch(sms);
    return match?.group(1)?.trim() ?? '';
  }

  String _fallbackMerchantName(String sms, String sender) {
    final hint = _extractMerchantHint(sms);
    if (hint.isNotEmpty) return hint;
    if (sender.isNotEmpty) return sender;
    return 'Unknown';
  }

  String _displayMerchant(String hint, String rememberedMerchant) {
    if (hint.isNotEmpty) return hint;
    return rememberedMerchant;
  }

  double _quickParseAmount(String sms) {
    final match =
        RegExp(r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)').firstMatch(sms);
    if (match == null) return 0;
    return double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
  }
}
