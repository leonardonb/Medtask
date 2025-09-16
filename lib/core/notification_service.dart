import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'settings_service.dart';

class NotificationService {
  static const String medsChannel = 'meds';
  static const String systemChannel = 'system';
  static const String customChannel = 'custom';

  static bool _inited = false;

  static String _normalizeChannelKey(String key) {
    switch (key) {
      case medsChannel:
      case systemChannel:
      case customChannel:
        return key;
      case 'meds_channel_custom_v4':
      case 'meds_custom':
      case 'meds_v4':
        return customChannel;
      case 'meds_channel_system':
      case 'system_default':
        return systemChannel;
      case 'meds_channel':
      case 'meds_default':
        return medsChannel;
      default:
        return medsChannel;
    }
  }

  static Future<void> init() async {
    if (_inited) return;
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: medsChannel,
          channelName: 'Lembretes de remédio',
          channelDescription: 'Alertas recorrentes para tomada de medicamentos',
          importance: NotificationImportance.Max,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: true,
          enableVibration: true,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Alarm,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: systemChannel,
          channelName: 'Som do sistema',
          channelDescription: 'Canal para tocar com som do sistema',
          importance: NotificationImportance.Max,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: true,
          enableVibration: true,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Alarm,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: customChannel,
          channelName: 'Som do app',
          channelDescription: 'Canal para tocar com som customizado do app',
          importance: NotificationImportance.Max,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: true,
          enableVibration: true,
          locked: true,
          soundSource: 'resource://raw/alarme',
          channelShowBadge: true,
        ),
      ],
      debug: false,
    );
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    _inited = true;
  }

  static Future<void> _ensureInit() async {
    if (!_inited) await init();
  }

  static Future<void> openNotificationSettings(String packageName) async {
    await _ensureInit();
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> showNow() async {
    await _ensureInit();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: medsChannel,
        title: 'Notificação imediata',
        body: 'Teste de notificação imediata',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> timerIn10s() async {
    await _ensureInit();
    final when = DateTime.now().add(const Duration(seconds: 10));
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: medsChannel,
        title: 'Agendado ~10s',
        body: 'Teste de agendamento em ~10 segundos',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: when.year,
        month: when.month,
        day: when.day,
        hour: when.hour,
        minute: when.minute,
        second: when.second,
        millisecond: when.millisecond,
        repeats: false,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  static Future<void> timerExactIn15s() async {
    await _ensureInit();
    final when = DateTime.now().add(const Duration(seconds: 15));
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: medsChannel,
        title: 'Agendado exato ~15s',
        body: 'Teste de agendamento exato em ~15 segundos',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: when.year,
        month: when.month,
        day: when.day,
        hour: when.hour,
        minute: when.minute,
        second: when.second,
        millisecond: when.millisecond,
        repeats: false,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  static Future<void> openBatteryOptimizationSettings() async {
    return;
  }

  static Future<String> _currentChannelKey() async {
    await _ensureInit();
    final choice = await SettingsService.getAlarmChoice();
    final key = SettingsService.channelKeyForChoice(choice);
    return _normalizeChannelKey(key);
  }

  static Future<void> scheduleSeries({
    required int baseId,
    required DateTime firstWhen,
    required String title,
    required String body,
    required String sound,
    required Duration repeatEvery,
    required int repeatCount,
    required String payload,
  }) async {
    await _ensureInit();
    final channel = await _currentChannelKey();
    for (int i = 0; i < repeatCount; i++) {
      final id = baseId + i;
      final when = firstWhen.add(repeatEvery * i);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channel,
          title: title,
          body: body,
          payload: {'k': payload},
          groupKey: payload,
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          locked: true,
        ),
        schedule: NotificationCalendar(
          year: when.year,
          month: when.month,
          day: when.day,
          hour: when.hour,
          minute: when.minute,
          second: when.second,
          millisecond: when.millisecond,
          repeats: false,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );
    }
  }

  static Future<void> cancelSeries(int baseId, int repeatCount) async {
    await _ensureInit();
    for (int i = 0; i < repeatCount; i++) {
      final id = baseId + i;
      await AwesomeNotifications().cancel(id);
      await AwesomeNotifications().cancelSchedule(id);
    }
  }

  static Future<void> cancelAllForMed(int medId, {String? medName, int maxPerMed = 32}) async {
    await _ensureInit();
    final base = medId * 1000;
    for (int i = 0; i < maxPerMed; i++) {
      final id = base + i;
      await AwesomeNotifications().cancel(id);
      await AwesomeNotifications().cancelSchedule(id);
    }
    final group = 'med:$medId';
    await AwesomeNotifications().cancelSchedulesByGroupKey(group);
    await AwesomeNotifications().cancelNotificationsByGroupKey(group);
  }

  static Future<void> cancelAllSchedules() async {
    await _ensureInit();
    await AwesomeNotifications().cancelAllSchedules();
  }
}
