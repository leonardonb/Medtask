import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationHelpers {
  static int _baseForMed(int medId) => medId * 1000;
  static int notificationIdFor(int medId, int index) => _baseForMed(medId) + index;
  static Future<void> cancelAllForMed(int medId, {int maxPerMed = 16}) async {
    final base = _baseForMed(medId);
    for (int i = 0; i < maxPerMed; i++) {
      await AwesomeNotifications().cancel(base + i);
    }
  }
}
