import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const String channelId = 'med_channel_id_v2';
  static const String channelName = 'Lembretes de Remédio';
  static const String channelDesc = 'Notificações para próximas doses';

  static bool _tzConfigured = false;

  static Future<void> _configureLocalTimeZone() async {
    if (_tzConfigured) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    _tzConfigured = true;
  }

  static Future<void> init({String defaultRawSound = 'alert'}) async {
    await _configureLocalTimeZone();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(init);
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(defaultRawSound),
      ),
    );
  }

  static Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  static Future<void> openNotificationSettings(String packageName) async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: {'android.provider.extra.APP_PACKAGE': packageName},
    );
    await intent.launch();
  }

  static Future<void> openExactAlarmsSettings() async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
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

  static Future<void> showNow({
    int id = 7777,
    String title = 'Teste imediato',
    String body = 'Canal/permite OK?',
  }) async {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    await _plugin.show(id, title, body, NotificationDetails(android: android));
  }

  // Timers locais (diagnóstico com app aberto)
  static Future<void> timerIn10s() async {
    await Future.delayed(const Duration(seconds: 10));
    await showNow(id: 7001, title: 'Timer +10s', body: 'Disparo local.');
  }

  static Future<void> timerExactIn15s() async {
    await Future.delayed(const Duration(seconds: 15));
    await showNow(id: 7002, title: 'Timer +15s', body: 'Disparo local.');
  }

  // -------------------- API de agendamento --------------------

  static Future<void> scheduleOne({
    required int id,
    required DateTime when, // horário LOCAL desejado
    required String title,
    required String body,
    String? payload,
  }) async {
    await _configureLocalTimeZone();
    var utc = when.toUtc();
    final nowUtc = DateTime.now().toUtc();
    if (!utc.isAfter(nowUtc)) {
      utc = nowUtc.add(const Duration(seconds: 5));
    }
    final tzWhenUtc = tz.TZDateTime.from(utc, tz.UTC);

    try {
      await _scheduleOneInternal(
        id: id,
        when: tzWhenUtc,
        title: title,
        body: body,
        payload: payload,
        exact: true,
      );
    } on PlatformException {
      await _scheduleOneInternal(
        id: id,
        when: tzWhenUtc,
        title: title,
        body: body,
        payload: payload,
        exact: false,
      );
    }
  }

  static Future<void> scheduleSeries({
    required int baseId,
    required DateTime firstWhen, // local
    required String title,
    required String body,
    String? payload,
    Duration repeatEvery = const Duration(minutes: 5),
    int repeatCount = 12, // 1h de repetições
  }) async {
    await cancelSeries(baseId, repeatCount);

    // agenda o primeiro
    await scheduleOne(
      id: baseId,
      when: firstWhen,
      title: title,
      body: body,
      payload: payload,
    );

    // agenda o resto sem "flood"
    for (int i = 1; i <= repeatCount; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      await scheduleOne(
        id: baseId + i,
        when: firstWhen.add(repeatEvery * i),
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  static Future<void> cancelSeries(int baseId, int repeatCount) async {
    for (int i = 0; i <= repeatCount; i++) {
      await _plugin.cancel(baseId + i);
    }
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<void> _scheduleOneInternal({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
    String? payload,
    required bool exact,
  }) async {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    // Nunca deixe ir pro passado
    final now = tz.TZDateTime.now(tz.UTC);
    if (!when.isAfter(now)) {
      when = now.add(const Duration(seconds: 5));
    }
    final diff = when.difference(now);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        NotificationDetails(android: android),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } on PlatformException {
      // Se ainda falhar: fallback local quando curto (com app aberto)
      if (diff > Duration.zero && diff <= const Duration(minutes: 30)) {
        Future.delayed(diff, () {
          showNow(id: id, title: title, body: body);
        });
      } else {
        rethrow;
      }
    }
  }
}
