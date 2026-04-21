/// SpendSense - Digest scheduler wrapper.
/// The notification service owns the actual scheduled reminder.

import '../services/notification_service.dart';

class DigestScheduler {
  DigestScheduler._();
  static final DigestScheduler instance = DigestScheduler._();

  Future<void> sync(int pendingCount) {
    return NotificationService.instance.syncDigestSchedule(pendingCount);
  }

  Future<void> triggerNow(int pendingCount) {
    return NotificationService.instance.showDigestNotification(pendingCount);
  }
}
