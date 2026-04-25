/// SpendSense - central app orchestrator.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/transaction.dart';
import '../services/claude_service.dart';
import '../services/digest_scheduler.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/sheets_service.dart';
import '../services/sms_service.dart';
import '../services/voice_service.dart';
import '../services/local_parser_service.dart';
import '../services/secure_storage_service.dart';

enum TxState {
  idle,
  smsReceived,
  processing,
  autoLogged,
  awaitingUser,
  confirmed,
  logged,
  error,
}

class AppState extends ChangeNotifier {
  final SmsService _sms;
  final ClaudeService _claude;
  final LocalStorageService _local;
  final SheetsService _sheets;
  final NotificationService _notif;
  final VoiceService _voice;
  final DigestScheduler _digest;
  final LocalParserService _localParser;
  final SecureStorageService _secure;

  AppState({
    SmsService? sms,
    ClaudeService? claude,
    LocalStorageService? local,
    SheetsService? sheets,
    NotificationService? notif,
    VoiceService? voice,
    DigestScheduler? digest,
    LocalParserService? localParser,
    SecureStorageService? secure,
  })  : _sms = sms ?? SmsService.instance,
        _claude = claude ?? ClaudeService.instance,
        _local = local ?? LocalStorageService.instance,
        _sheets = sheets ?? SheetsService.instance,
        _notif = notif ?? NotificationService.instance,
        _voice = voice ?? VoiceService.instance,
        _digest = digest ?? DigestScheduler.instance,
        _localParser = localParser ?? LocalParserService.instance,
        _secure = secure ?? SecureStorageService.instance;

  TxState _txState = TxState.idle;
  MyTransaction? _currentMyTransaction;
  List<MyTransaction> _pendingMyTransactions = [];
  List<String> _customCategories = [];
  bool _isVoiceListening = false;
  bool _isSmsReady = false;
  bool _notificationsReady = false;
  String? _errorMessage;

  TxState get txState => _txState;
  MyTransaction? get currentMyTransaction => _currentMyTransaction;
  List<MyTransaction> get pendingMyTransactions => _pendingMyTransactions;
  List<String> get allCategories =>
      [...AppConstants.defaultCategories, ..._customCategories];
  bool get isVoiceListening => _isVoiceListening;
  bool get isSmsReady => _isSmsReady;
  bool get notificationsReady => _notificationsReady;
  String? get errorMessage => _errorMessage;

  Future<void> initialise() async {
    await _local.database;
    await _secure.migrateFromPrefs();
    _notificationsReady = await _notif.initialise();
    await _voice.initialise();
    _isSmsReady = await _sms.initialise(_onPaymentSmsReceived);
    _customCategories = await _local.getCustomCategories();
    await _sms.processQueuedMessages();
    await _retryUnsyncedTransactions();
    await _loadPendingMyTransactions();

    if (!_isSmsReady) {
      _errorMessage =
          'SMS permission is required before SpendSense can listen in the background.';
    }

    if (!_notificationsReady) {
      _errorMessage ??=
          'Notification permission is recommended so SpendSense can prompt for low-confidence transactions.';
    }

    notifyListeners();
  }

  @visibleForTesting
  Future<void> onPaymentSmsReceived(String smsBody, String sender) async {
    return _onPaymentSmsReceived(smsBody, sender);
  }

  Future<void> _onPaymentSmsReceived(String smsBody, String sender) async {
    // 0. Deduplication check
    final fingerprint = _generateFingerprint(smsBody, sender);
    final existing = await _local.findByFingerprint(fingerprint);
    if (existing != null) {
      // ignore: avoid_print
      print('SpendSense: SMS deduplicated. Fingerprint: $fingerprint');
      return;
    }

    _setState(TxState.smsReceived);

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
      await _syncTransaction(transaction);
      return;
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

      if (memory.isDynamic) {
        // For dynamic peers, save as pending and trigger popup
        await _local.upsertTransaction(
          quickTransaction,
          needsUserInput: true,
          sender: sender,
          syncStatus: AppConstants.syncPending,
          fingerprint: fingerprint,
        );
        await _notif.showTransactionPopup(quickTransaction);
        await _loadPendingMyTransactions();
        _setState(TxState.awaitingUser);
      } else {
        // For static merchants, log silently
        await _local.upsertTransaction(
          quickTransaction,
          needsUserInput: false,
          sender: sender,
          syncStatus: AppConstants.syncPending,
          fingerprint: fingerprint,
        );
        await _syncTransaction(quickTransaction);
      }
      return;
    }

    // 3. Try Claude AI (Optional)
    final apiKey = await _secure.readSecret(AppConstants.prefClaudeApiKey);

    if (apiKey != null && apiKey.isNotEmpty) {
      _setState(TxState.processing);
      final transaction = await _claude.categorise(smsBody, allCategories);

      if (transaction != null) {
        _currentMyTransaction = transaction;

        if (transaction.confidence == AppConstants.confidenceHigh) {
          final confirmed = transaction.copyWith(isConfirmed: true);
          await _local.upsertTransaction(
            confirmed,
            needsUserInput: false,
            sender: sender,
            syncStatus: AppConstants.syncPending,
            fingerprint: fingerprint,
          );
          await _syncTransaction(confirmed);
          return;
        }

        await _local.upsertTransaction(
          transaction,
          needsUserInput: true,
          sender: sender,
          syncStatus: AppConstants.syncPending,
          fingerprint: fingerprint,
        );
        await _notif.showTransactionPopup(transaction);
        await _loadPendingMyTransactions();
        _setState(TxState.awaitingUser);
        return;
      }
    }

    // 4. Fallback to Manual Review
    final fallback = MyTransaction.manualReview(
      rawSms: smsBody,
      merchant: _fallbackMerchantName(smsBody, sender),
      amount: _quickParseAmount(smsBody),
    );

    await _local.upsertTransaction(
      fallback,
      needsUserInput: true,
      sender: sender,
      syncStatus: AppConstants.syncPending,
      lastError: 'Local parsing and AI classification unavailable/failed',
      fingerprint: fingerprint,
    );
    await _notif.showTransactionPopup(fallback);
    await _loadPendingMyTransactions();
    _setState(
      TxState.awaitingUser,
      error: 'Could not auto-process this payment. Saved for manual review.',
    );
  }

  @visibleForTesting
  String generateFingerprint(String sms, String sender) {
    return _generateFingerprint(sms, sender);
  }

  String _generateFingerprint(String sms, String sender) {
    // Generate a SHA-256 hash of the full SMS body + sender.
    // This is "Strict Raw Body" deduplication—mathematically foolproof if the SMS contains a unique ID.
    final bytes = utf8.encode('$sender|$sms');
    return sha256.convert(bytes).toString();
  }

  Future<void> confirmCategory(
    MyTransaction transaction,
    String category, {
    bool isDynamic = false,
  }) async {
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
    await _notif.dismissTransactionNotification();
    await _syncTransaction(confirmed);
    await _loadPendingMyTransactions();
  }

  Future<bool> confirmWithVoice(MyTransaction transaction) async {
    _isVoiceListening = true;
    notifyListeners();

    final voiceText = await _voice.listen();

    _isVoiceListening = false;
    notifyListeners();

    if (voiceText == null || voiceText.isEmpty) return false;

    final understood = await _claude.understandVoiceNote(
        voiceText, transaction, allCategories);
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
    final synced = await _syncTransaction(confirmed);
    if (synced) {
      _setState(TxState.confirmed);
    }
    return true;
  }

  Future<void> loadDigest() async {
    await _loadPendingMyTransactions();
  }

  Future<void> confirmAll(Map<String, String> categoryMap,
      {Map<String, bool>? dynamicMap}) async {
    final transactions = List<MyTransaction>.from(_pendingMyTransactions);

    for (final transaction in transactions) {
      final category = categoryMap[transaction.id] ?? 'Others';
      final isDynamic = dynamicMap?[transaction.id] ?? false;
      await confirmCategory(transaction, category, isDynamic: isDynamic);
    }

    await _notif.dismissDigestNotification();
    await _loadPendingMyTransactions();
  }

  Future<void> triggerDigestForTesting() async {
    await _digest.triggerNow(_pendingMyTransactions.length);
  }

  Future<bool> _syncTransaction(MyTransaction transaction) async {
    _setState(TxState.processing);

    final success = await _sheets.logMyTransaction(transaction);
    if (success) {
      await _local.markSynced(transaction.id);
      await _loadPendingMyTransactions();
      _setState(TxState.logged);
      return true;
    }

    await _local.markSyncFailed(
      transaction.id,
      'Could not reach Google Sheets. Will retry later.',
    );
    await _loadPendingMyTransactions();
    _setState(
      TxState.error,
      error:
          'Could not reach Google Sheets. Transaction saved locally for retry.',
    );
    return false;
  }

  Future<void> _retryUnsyncedTransactions() async {
    final retryable = await _local.getConfirmedPendingSync();
    if (retryable.isEmpty) return;

    for (final transaction in retryable) {
      final success = await _sheets.logMyTransaction(transaction);
      if (success) {
        await _local.markSynced(transaction.id);
      } else {
        await _local.markSyncFailed(
          transaction.id,
          'Retry failed. Will try again later.',
        );
      }
    }
  }

  Future<void> _loadPendingMyTransactions() async {
    _pendingMyTransactions = await _local.getPending();
    await _digest.sync(_pendingMyTransactions.length);
    notifyListeners();
  }

  void _setState(TxState state, {String? error}) {
    _txState = state;
    _errorMessage = error;
    notifyListeners();
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

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> addCustomCategory(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    // Capitalize first letter
    final formattedName =
        cleanName[0].toUpperCase() + cleanName.substring(1).toLowerCase();

    if (allCategories.contains(formattedName)) return;

    await _local.saveCustomCategory(formattedName);
    _customCategories = await _local.getCustomCategories();
    notifyListeners();
  }
}

