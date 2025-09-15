import 'dart:io';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'settings_service.dart';

class NotificationService {
  static bool _initialized = false;

  static Future<void> init({bool debug = false}) async {
    if (_initialized) return;
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'meds_channel_system_v4',
            channelName: 'Lembretes (Sistema)',
            channelDescription: 'Som padrão do sistema',
            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Alarm,
            importance: NotificationImportance.Max,
            enableVibration: true,
            enableLights: true,
          ),
          NotificationChannel(
            channelKey: 'meds_channel_custom_v4',
            channelName: 'Lembretes (Alarme do app)',
            channelDescription: 'Usa o arquivo alarme.mp3 do app',
            playSound: true,
            soundSource: 'resource://raw/alarme',
            importance: NotificationImportance.Max,
            enableVibration: true,
            enableLights: true,
          ),
        ],
        debug: debug,
      );
      _initialized = true;
    } on PlatformException {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'meds_channel_system_v4',
            channelName: 'Lembretes (Sistema)',
            channelDescription: 'Som padrão do sistema',
            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Alarm,
            importance: NotificationImportance.Max,
            enableVibration: true,
            enableLights: true,
          ),
          NotificationChannel(
            channelKey: 'meds_channel_custom_v4',
            channelName: 'Lembretes (Alarme do app)',
            channelDescription: 'Som custom indisponível; usando sistema',
            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Alarm,
            importance: NotificationImportance.Max,
            enableVibration: true,
            enableLights: true,
          ),
        ],
        debug: debug,
      );
      _initialized = true;
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    return AwesomeNotifications().isNotificationAllowed();
  }

  static Future<void> openNotificationSettings(String packageName) async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: {'android.provider.extra.APP_PACKAGE': packageName},
    );
    await intent.launch();
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  static Future<void> showNow() async {
    final choice = await SettingsService.getAlarmChoice();
    final key = SettingsService.channelKeyForChoice(choice);
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: key,
        title: 'Ei, olha a hora do remédio…',
        body: 'Notificação imediata.',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> timerIn10s() async {
    final when = DateTime.now().add(const Duration(seconds: 10));
    await scheduleOne(
      id: DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      when: when,
      title: 'Lembrete em 10s',
      body: 'Disparado com agendamento padrão.',
      exactIfPossible: false,
    );
  }

  static Future<void> timerExactIn15s() async {
    final when = DateTime.now().add(const Duration(seconds: 15));
    await scheduleOne(
      id: DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      when: when,
      title: 'Lembrete exato em 15s',
      body: 'Disparado com alarme exato.',
      exactIfPossible: true,
    );
  }

  static Future<void> scheduleOne({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    bool exactIfPossible = true,
  }) async {
    final choice = await SettingsService.getAlarmChoice();
    final key = SettingsService.channelKeyForChoice(choice);
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: key,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(
        date: when,
        preciseAlarm: exactIfPossible,
      ),
    );
  }

  static Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    bool exactIfPossible = true,
  }) async {
    final choice = await SettingsService.getAlarmChoice();
    final key = SettingsService.channelKeyForChoice(choice);
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: key,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: hour,
        minute: minute,
        second: 0,
        repeats: true,
        preciseAlarm: exactIfPossible,
      ),
    );
  }

  static Future<void> scheduleSeries({
    required int baseId,
    required DateTime firstWhen,
    required String title,
    required String body,
    String? sound,
    required Duration repeatEvery,
    required int repeatCount,
    String? payload,
  }) async {
    final choice = await SettingsService.getAlarmChoice();
    final key = SettingsService.channelKeyForChoice(choice);
    for (int i = 0; i < repeatCount; i++) {
      final when = firstWhen.add(repeatEvery * i);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: baseId + i,
          channelKey: key,
          title: title,
          body: body,
          payload: payload == null ? null : {'p': payload},
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(
          date: when,
          preciseAlarm: true,
        ),
      );
    }
  }

  static Future<void> cancelSeries(int baseId, int repeatCount) async {
    for (int i = 0; i < repeatCount; i++) {
      final id = baseId + i;
      await AwesomeNotifications().cancel(id);
      await AwesomeNotifications().cancelSchedule(id);
    }
  }
}
