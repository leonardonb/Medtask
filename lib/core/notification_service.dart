import 'dart:typed_data';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';

class NotificationService {
  static const String medsChannel = 'meds';
  static const String systemChannel = 'system';
  static const String customChannel = 'custom';
  static const String vibrateChannel = 'vibrate';

  // Canais físicos versionados
  static const String _systemAlarmV = 'system_alarm_v2';
  static const String _vibrateOnlyV = 'vibrate_only_v2';

  // Versão do "esquema" de canais. BUMP se adicionar/alterar canais.
  static const int _schemaVersion = 2;
  static bool _inited = false;

  static String _normalizeChannelKey(String key) {
    switch (key) {
      case medsChannel:
        return medsChannel;
      case customChannel:
      case 'meds_channel_custom_v4':
      case 'meds_custom':
      case 'meds_v4':
        return customChannel;
      case systemChannel:
      case 'system_default':
      case 'meds_channel_system':
      case 'meds_channel_system_v4':
        return _systemAlarmV;
      case vibrateChannel:
        return _vibrateOnlyV;
      case 'meds_channel':
      case 'meds_default':
        return medsChannel;
      default:
        return medsChannel;
    }
  }

  static Future<void> init() async {
    // Migração de canais baseada em versão
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('notif_schema_version') ?? 0;
    final mustRecreate = stored < _schemaVersion;

    if (_inited && !mustRecreate) return;

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
        // Mantemos o "system" legado só para compatibilidade visual
        NotificationChannel(
          channelKey: systemChannel,
          channelName: 'Som do sistema (legado)',
          channelDescription: 'Canal antigo com som de notificação',
          importance: NotificationImportance.Max,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: true,
          enableVibration: true,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Notification,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: _systemAlarmV,
          channelName: 'Som do sistema (alarme)',
          channelDescription: 'Canal do sistema usando toque de alarme',
          importance: NotificationImportance.Max,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: true,
          enableVibration: true,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Alarm,
          channelShowBadge: true,
          criticalAlerts: true,
        ),
        NotificationChannel(
          channelKey: customChannel,
          channelName: 'Som do app',
          channelDescription: 'Canal com som customizado do app',
          importance: NotificationImportance.Max,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: true,
          enableVibration: true,
          locked: true,
          soundSource: 'resource://raw/alarme',
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: _vibrateOnlyV,
          channelName: 'Apenas vibrar',
          channelDescription: 'Sem som, apenas vibração',
          importance: NotificationImportance.Max,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: false,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 600]),
          locked: true,
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
    if (mustRecreate) {
      await prefs.setInt('notif_schema_version', _schemaVersion);
    }
  }

  static Future<void> _ensureInit() async {
    await init();
  }

  static Future<void> openNotificationSettings(String packageName) async {
    await _ensureInit();
    final ok = await AwesomeNotifications().isNotificationAllowed();
    if (!ok) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<String> _currentChannelKey() async {
    await _ensureInit();
    final choice = await SettingsService.getAlarmChoice();
    final logical = SettingsService.channelKeyForChoice(choice);
    return _normalizeChannelKey(logical);
  }

  static Future<void> showNow() async {
    final channel = await _currentChannelKey();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: channel,
        title: 'Notificação imediata',
        body: 'Teste de notificação imediata',
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        locked: true,
        category: NotificationCategory.Alarm,
      ),
    );
  }

  static Future<void> previewSelectedSound() async {
    final channel = await _currentChannelKey();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
        channelKey: channel,
        title: 'Prévia',
        body: 'Canal selecionado',
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        locked: false,
        category: NotificationCategory.Alarm,
      ),
    );
  }

  static Future<void> timerIn10s() async {
    final when = DateTime.now().add(const Duration(seconds: 10));
    final channel = await _currentChannelKey();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: channel,
        title: 'Agendado ~10s',
        body: 'Teste de agendamento em ~10 segundos',
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        locked: true,
        category: NotificationCategory.Alarm,
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
    final when = DateTime.now().add(const Duration(seconds: 15));
    final channel = await _currentChannelKey();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: channel,
        title: 'Agendado exato ~15s',
        body: 'Teste de agendamento exato em ~15 segundos',
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        locked: true,
        category: NotificationCategory.Alarm,
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
          category: NotificationCategory.Alarm,
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
    for (int i = 0; i < repeatCount; i++) {
      final id = baseId + i;
      await AwesomeNotifications().cancel(id);
      await AwesomeNotifications().cancelSchedule(id);
    }
  }

  static Future<void> cancelAllForMed(int medId, {String? medName, int maxPerMed = 32}) async {
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
    await AwesomeNotifications().cancelAllSchedules();
  }
}
