/// SpendSense - Notification service.

import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../main.dart' show navigatorKey;
import '../core/constants.dart';
import '../models/transaction.dart';
import '../services/local_storage_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _timeZonesReady = false;

  Future<bool> initialise() async {
    await _ensureTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTap,
    );

    const channel = AndroidNotificationChannel(
      AppConstants.notifChannelId,
      AppConstants.notifChannelName,
      importance: Importance.high,
      enableVibration: true,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    final granted = await androidPlugin?.requestNotificationsPermission();

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse != null) {
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        () => _onTap(launchDetails!.notificationResponse!),
      );
    }

    return granted ?? true;
  }

  Future<void> showTransactionPopup(MyTransaction transaction) async {
    final payload = jsonEncode({
      'kind': 'transaction',
      'id': transaction.id,
    });

    await _plugin.show(
      AppConstants.notifTransactionId,
      '₹${transaction.amount.toStringAsFixed(0)} · ${transaction.merchant}',
      'Tap to categorise',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelId,
          AppConstants.notifChannelName,
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: false,
          fullScreenIntent: true,
        ),
      ),
      payload: payload,
    );

    // If app is in foreground, auto-open the popup for immediate feedback
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamed('/popup', arguments: transaction);
    }
  }

  Future<void> dismissTransactionNotification() async {
    await _plugin.cancel(AppConstants.notifTransactionId);
  }

  Future<void> dismissDigestNotification() async {
    await _plugin.cancel(AppConstants.notifDigestId);
  }

  Future<void> syncDigestSchedule(int pendingCount) async {
    await _ensureTimeZones();
    await _plugin.cancel(AppConstants.notifDigestId);

    if (pendingCount == 0) {
      return;
    }

    final scheduledDate = _nextDigestTime();
    final title = pendingCount == 1
        ? '1 transaction needs attention'
        : '$pendingCount transactions need attention';

    await _plugin.zonedSchedule(
      AppConstants.notifDigestId,
      title,
      'Open SpendSense to review your pending transactions',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelId,
          AppConstants.notifChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({'kind': 'digest'}),
    );
  }

  Future<void> showDigestNotification(int pendingCount) async {
    if (pendingCount == 0) return;

    final title = pendingCount == 1
        ? '1 transaction needs attention'
        : '$pendingCount transactions need attention';

    await _plugin.show(
      AppConstants.notifDigestId,
      title,
      'Open SpendSense to review your pending transactions',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelId,
          AppConstants.notifChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: jsonEncode({'kind': 'digest'}),
    );
  }

  Future<void> _ensureTimeZones() async {
    if (_timeZonesReady) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(AppConstants.digestTimeZone));
    _timeZonesReady = true;
  }

  tz.TZDateTime _nextDigestTime() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      AppConstants.digestHour,
      AppConstants.digestMinute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  @pragma('vm:entry-point')
  static Future<void> _onTap(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) {
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        () => _onTap(response),
      );
      return;
    }

    if (parsed['kind'] == 'digest') {
      await nav.pushNamed('/digest');
      return;
    }

    final transactionId = parsed['id'] as String?;
    if (transactionId == null || transactionId.isEmpty) return;

    final transaction =
        await LocalStorageService.instance.findTransactionById(transactionId);
    if (transaction != null) {
      await nav.pushNamed('/popup', arguments: transaction);
    }
  }
}
