import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';

class Permissions {
  static Future<void> ensureNotificationAndAlarmPermissions() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final sdk = info.version.sdkInt;

      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (!allowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      if (sdk >= 31) {
        final intent = AndroidIntent(action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM');
        await intent.launch();
      }
    }
  }
}
