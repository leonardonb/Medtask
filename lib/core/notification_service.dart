import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';

class NotificationService {
  static const String _baseChannelKey = 'meds_channel';
  static const String _channelName = 'Lembretes de Remédio';
  static const String _channelDesc = 'Alarmes e lembretes de doses';

  static String? _tz;
  static late String _defaultSound;
  static final Set<String> _knownSounds = <String>{};

  static Future<void> init({
    String defaultRawSound = 'alert',
    List<String> otherRawSounds = const [],
    bool debug = false,
  }) async {
    _defaultSound = _sanitizeSound(defaultRawSound);
    _knownSounds
      ..clear()
      ..add(_defaultSound)
      ..addAll(otherRawSounds.map(_sanitizeSound));

    final channels = <NotificationChannel>[
      _buildChannel(channelKeyForSound(null), _defaultSound),
      ..._knownSounds
          .where((s) => s != _defaultSound)
          .map((s) => _buildChannel(channelKeyForSound(s), s)),
    ];

    await AwesomeNotifications().initialize(null, channels, debug: debug);

    _tz = await AwesomeNotifications().getLocalTimeZoneIdentifier();

    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> registerExtraSounds(List<String> sounds) async {
    final newOnes = sounds
        .map(_sanitizeSound)
        .where((s) => !_knownSounds.contains(s) && s.isNotEmpty)
        .toList();
    if (newOnes.isEmpty) return;

    for (final s in newOnes) {
      await AwesomeNotifications().setChannel(_buildChannel(channelKeyForSound(s), s));
      _knownSounds.add(s);
    }
  }

  static NotificationChannel _buildChannel(String key, String sound) {
    return NotificationChannel(
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
  }

  static String channelKeyForSound(String? sound) {
    final s = sound == null ? null : _sanitizeSound(sound);
    if (s == null || s.isEmpty || !_knownSounds.contains(s) || s == _defaultSound) {
      return _baseChannelKey;
    }
    return '$_baseChannelKey\_$s';
  }

  static String _sanitizeSound(String raw) =>
      raw.trim().toLowerCase().replaceAll(' ', '_');

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
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }

  static Future<void> showNow({
    int id = 7777,
    String title = 'Lembrete',
    String body = 'Teste imediato',
    String? sound,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKeyForSound(sound),
        title: title,
        body: body,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        autoDismissible: true,
      ),
    );
  }

  static Future<void> timerIn10s() async =>
      Future.delayed(const Duration(seconds: 10),
              () => showNow(id: 7001, title: 'Timer +10s', body: 'Local timer'));

  static Future<void> timerExactIn15s() async =>
      Future.delayed(const Duration(seconds: 15),
              () => showNow(id: 7002, title: 'Timer +15s', body: 'Local timer'));

  static Future<void> scheduleOne({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
    String? sound,
    bool exactIfPossible = true,
  }) async {
    final runAt = _safeFuture(when);
    _tz ??= await AwesomeNotifications().getLocalTimeZoneIdentifier();

    final channelKey = channelKeyForSound(sound);
    final precise = exactIfPossible && await _canUseExactAlarm();

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
        year: runAt.year,
        month: runAt.month,
        day: runAt.day,
        hour: runAt.hour,
        minute: runAt.minute,
        second: runAt.second,
        millisecond: 0,
        timeZone: _tz,
        preciseAlarm: precise,
        allowWhileIdle: true,
        repeats: false,
      ),
    );
  }

  static Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    String title = 'Ei, olha a hora do remédio…',
    String body = 'Cadê você? Lembra do remédio!!!',
    String? payload,
    String? sound,
    bool exactIfPossible = true,
  }) async {
    final now = DateTime.now();
    var first = DateTime(now.year, now.month, now.day, hour, minute);
    if (!first.isAfter(now)) {
      first = first.add(const Duration(days: 1));
    }
    await scheduleOne(
      id: id,
      when: first,
      title: title,
      body: body,
      payload: payload,
      sound: sound,
      exactIfPossible: exactIfPossible,
    );
  }

  static Future<void> scheduleSeries({
    required int baseId,
    required DateTime firstWhen,
    required String title,
    required String body,
    String? payload,
    String? sound,
    Duration repeatEvery = const Duration(minutes: 5),
    int repeatCount = 12,
    bool exactIfPossible = true,
  }) async {
    await cancelSeries(baseId, repeatCount);
    for (int i = 0; i <= repeatCount; i++) {
      await scheduleOne(
        id: baseId + i,
        when: firstWhen.add(repeatEvery * i),
        title: title,
        body: body,
        payload: payload,
        sound: sound,
        exactIfPossible: exactIfPossible,
      );
      await Future.delayed(const Duration(milliseconds: 25));
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

  static Future<bool> _canUseExactAlarm() async {
    if (!Platform.isAndroid) return false;
    return true;
  }

  static DateTime _safeFuture(DateTime when) {
    final now = DateTime.now();
    return when.isAfter(now) ? when : now.add(const Duration(seconds: 2));
  }
}
