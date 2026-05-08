/// SpendSense - central app orchestrator.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../models/transaction.dart';
import '../services/digest_scheduler.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';
import '../services/voice_service.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';
import '../services/sms_orchestrator.dart';
import '../services/contact_service.dart';

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

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final SmsService _sms;
  final LocalStorageService _local;
  final NotificationService _notif;
  final VoiceService _voice;
  final DigestScheduler _digest;
  final SecureStorageService _secure;
  final SyncService _sync;
  final SmsOrchestrator _orchestrator;

  AppState({
    SmsService? sms,
    LocalStorageService? local,
    NotificationService? notif,
    VoiceService? voice,
    DigestScheduler? digest,
    SecureStorageService? secure,
    SyncService? sync,
    SmsOrchestrator? orchestrator,
  })  : _sms = sms ?? SmsService.instance,
        _local = local ?? LocalStorageService.instance,
        _notif = notif ?? NotificationService.instance,
        _voice = voice ?? VoiceService.instance,
        _digest = digest ?? DigestScheduler.instance,
        _secure = secure ?? SecureStorageService.instance,
        _sync = sync ?? SyncService.instance,
        _orchestrator = orchestrator ?? SmsOrchestrator.instance;

  TxState _txState = TxState.idle;
  MyTransaction? _currentMyTransaction;
  List<MyTransaction> _pendingMyTransactions = [];
  List<String> _customCategories = [];
  bool _isVoiceListening = false;
  bool _isSmsReady = false;
  bool _notificationsReady = false;
  bool _isBatteryOptimized = false;
  String? _errorMessage;

  TxState get txState => _txState;
  MyTransaction? get currentMyTransaction => _currentMyTransaction;
  List<MyTransaction> get pendingMyTransactions => _pendingMyTransactions;
  List<String> get allCategories =>
      [...AppConstants.defaultCategories, ..._customCategories];
  bool get isVoiceListening => _isVoiceListening;
  bool get isSmsReady => _isSmsReady;
  bool get notificationsReady => _notificationsReady;
  bool get isBatteryOptimized => _isBatteryOptimized;
  String? get errorMessage => _errorMessage;

  Future<void> initialise() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_processing_sms', false); // Reset lock

      await _local.database;
      await _secure.migrateFromPrefs();
      _notificationsReady = await _notif.initialise();
      await _voice.initialise();
      await ContactService.instance.initialise();
      _isSmsReady = await _sms.initialise(_onPaymentSmsReceived);
      _customCategories = await _local.getCustomCategories();

      // Check for battery optimization
      _isBatteryOptimized = await _checkBatteryOptimization();

      await _sms.processQueuedMessages();
      await _sync.retryUnsyncedTransactions();
      await _loadPendingMyTransactions();

      if (!_isSmsReady) {
        _errorMessage =
            'SMS permission is required before SpendSense can listen in the background.';
      }

      if (!_notificationsReady) {
        _errorMessage ??=
            'Notification permission is recommended so SpendSense can prompt for low-confidence transactions.';
      }
    } catch (e) {
      debugPrint('SpendSense Critical Error during init: $e');
      _errorMessage = 'Application failed to start correctly: $e';
    } finally {
      notifyListeners();
    }
  }

  @visibleForTesting
  Future<void> onPaymentSmsReceived(String smsBody, String sender) async {
    return _onPaymentSmsReceived(smsBody, sender);
  }

  Future<void> _onPaymentSmsReceived(String smsBody, String sender) async {
    _setState(TxState.smsReceived);

    final result = await _orchestrator.processSms(
      smsBody,
      sender,
      allCategories: allCategories,
      onTransactionFound: (tx) {
        _currentMyTransaction = tx;
        notifyListeners();
      },
    );

    switch (result) {
      case SmsProcessingResult.deduplicated:
        // ignore: avoid_print
        print('SpendSense: SMS deduplicated.');
        _setState(TxState.idle);
        break;
      case SmsProcessingResult.autoLogged:
        await _loadPendingMyTransactions();
        _setState(TxState.logged);
        break;
      case SmsProcessingResult.awaitingUser:
        await _loadPendingMyTransactions();
        _setState(TxState.awaitingUser);
        break;
      case SmsProcessingResult.error:
        _setState(TxState.error, error: 'Failed to process SMS');
        break;
    }
  }

  @visibleForTesting
  String generateFingerprint(String sms, String sender) {
    return _orchestrator.generateFingerprint(sms, sender);
  }

  Future<void> confirmCategory(
    MyTransaction transaction,
    String category, {
    bool isDynamic = false,
  }) async {
    _setState(TxState.processing);

    // Perform local processing (DB + Mem)
    await _orchestrator.confirmCategory(transaction, category,
        isDynamic: isDynamic);

    // Refresh UI immediately after DB update
    await _loadPendingMyTransactions();
    _setState(TxState.confirmed);
  }

  Future<bool> confirmWithVoice(MyTransaction transaction) async {
    final confirmedTx = await _orchestrator.confirmWithVoice(
      transaction,
      allCategories,
      (listening) {
        _isVoiceListening = listening;
        notifyListeners();
      },
    );

    if (confirmedTx != null) {
      await _loadPendingMyTransactions();
      _setState(TxState.confirmed);
      return true;
    }
    return false;
  }

  Future<void> loadDigest() async {
    await _loadPendingMyTransactions();
  }

  Future<void> confirmAll(Map<String, String> categoryMap,
      {Map<String, bool>? dynamicMap}) async {
    _setState(TxState.processing);

    // confirmAll in orchestrator is now fast as confirmCategory is non-blocking for sync
    await _orchestrator.confirmAll(_pendingMyTransactions, categoryMap,
        dynamicMap: dynamicMap);

    await _loadPendingMyTransactions();
    _setState(TxState.confirmed);
  }

  Future<void> triggerDigestForTesting() async {
    await _digest.triggerNow(_pendingMyTransactions.length);
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

  /// Checks if the app is currently battery optimized.
  Future<bool> _checkBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status != PermissionStatus.granted;
  }

  /// Requests the user to disable battery optimization for the app.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (await Permission.ignoreBatteryOptimizations.request().isGranted) {
      _isBatteryOptimized = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('SpendSense: App resumed. Refreshing data...');
      _loadPendingMyTransactions();
      _sms.processQueuedMessages();
      _sync.retryUnsyncedTransactions();
    }
  }
}
