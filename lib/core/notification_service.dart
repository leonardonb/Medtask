import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';

class NotificationService {
  static const _channelKey = 'meds_channel';
  static const _channelName = 'Lembretes de Remédio';
  static const _channelDesc = 'Alarmes e lembretes de doses';
  static String? _tz;
  static late String _defaultSound;

  static Future<void> init({
    String defaultRawSound = 'alert',
    List<String> otherRawSounds = const [],
  }) async {
    _defaultSound = defaultRawSound;
    final channels = <NotificationChannel>[
      _buildChannel(_channelKey, defaultRawSound),
      ...otherRawSounds
          .map((s) => _buildChannel(channelKeyForSound(s), s)),
    ];

    await AwesomeNotifications().initialize(
      null, // usa ícone do app
      channels,
      debug: false,
    );

    _tz = await AwesomeNotifications().getLocalTimeZoneIdentifier();

    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static NotificationChannel _buildChannel(String key, String sound) =>
      NotificationChannel(
        channelKey: key,
        channelName: _channelName,
        channelDescription: _channelDesc,
        importance: NotificationImportance.Max,
        playSound: true,
        defaultRingtoneType: DefaultRingtoneType.Alarm,
        soundSource: 'resource://raw/$sound',
        enableVibration: true,
        criticalAlerts: true,
        channelShowBadge: true,
      );

  static String channelKeyForSound(String? sound) {
    if (sound == null || sound.isEmpty || sound == _defaultSound) {
      return _channelKey;
    }
    return '${_channelKey}_$sound';
  }

  static Future<bool> areNotificationsEnabled() =>
      AwesomeNotifications().isNotificationAllowed();

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

  // ---- imediata (teste rápido) ----
  static Future<void> showNow({
    int id = 7777,
    String title = 'Lembrete',
    String body = 'Teste imediato',
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: _channelKey,
        title: title,
        body: body,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        autoDismissible: true,
      ),
    );
  }

  // timers locais só para diagnóstico com app aberto
  static Future<void> timerIn10s() async =>
      Future.delayed(const Duration(seconds: 10),
              () => showNow(id: 7001, title: 'Timer +10s', body: 'Local timer'));
  static Future<void> timerExactIn15s() async =>
      Future.delayed(const Duration(seconds: 15),
              () => showNow(id: 7002, title: 'Timer +15s', body: 'Local timer'));

  // ---- API de agendamento usada pela VM ----
  static Future<void> scheduleOne({
    required int id,
    required DateTime when, // horário local
    required String title,
    required String body,
    String? payload,
    String channelKey = _channelKey,
  }) async {
    // nunca agenda no passado
    var w = when;
    final now = DateTime.now();
    if (!w.isAfter(now)) {
      w = now.add(const Duration(seconds: 2));
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        autoDismissible: true,
        payload: payload == null ? null : {'p': payload},
      ),
      schedule: NotificationCalendar(
        year: w.year,
        month: w.month,
        day: w.day,
        hour: w.hour,
        minute: w.minute,
        second: w.second,
        timeZone: _tz,
        preciseAlarm: true,
        allowWhileIdle: true,
        repeats: false,
      ),
    );
  }

  /// Agenda uma série (1h repetindo a cada 5 min, por padrão).
  static Future<void> scheduleSeries({
    required int baseId,
    required DateTime firstWhen,
    required String title,
    required String body,
    String? payload,
    String channelKey = _channelKey,
    Duration repeatEvery = const Duration(minutes: 5),
    int repeatCount = 12,
  }) async {
    await cancelSeries(baseId, repeatCount);
    for (int i = 0; i <= repeatCount; i++) {
      await scheduleOne(
        id: baseId + i,
        when: firstWhen.add(repeatEvery * i),
        title: title,
        body: body,
        payload: payload,
        channelKey: channelKey,
      );
      await Future.delayed(const Duration(milliseconds: 20)); // evita flood
    }
  }

  static Future<void> cancelSeries(int baseId, int repeatCount) async {
    for (int i = 0; i <= repeatCount; i++) {
      await AwesomeNotifications().cancel(baseId + i);
    }
  }

  static Future<void> cancel(int id) =>
      AwesomeNotifications().cancel(id);

  static Future<void> cancelAll() =>
      AwesomeNotifications().cancelAll();
}
