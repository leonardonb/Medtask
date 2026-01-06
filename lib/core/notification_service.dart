import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_service.dart';

class NotificationService {
  static final AwesomeNotifications _awesome = AwesomeNotifications();
  static const MethodChannel _channel = MethodChannel('medtask/settings');

  static Future<void> init() async {
    await SettingsService.init();

    await _awesome.initialize(
      null,
      [
        NotificationChannel(
          channelKey: SettingsService.channelKeyForChoice(AlarmChoice.system),
          channelName: 'Lembretes (sistema)',
          channelDescription: 'Notificações usando o som padrão do sistema',
          defaultColor: const Color(0xFF4CAF50),
          importance: NotificationImportance.High,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: SettingsService.channelKeyForChoice(AlarmChoice.custom),
          channelName: 'Lembretes (som do app)',
          channelDescription: 'Notificações usando som do app',
          defaultColor: const Color(0xFF4CAF50),
          importance: NotificationImportance.High,
          playSound: true,
          soundSource: 'resource://raw/alarme',
        ),
        NotificationChannel(
          channelKey: SettingsService.channelKeyForChoice(AlarmChoice.vibrate),
          channelName: 'Lembretes (vibrar)',
          channelDescription: 'Notificações apenas com vibração',
          defaultColor: const Color(0xFF4CAF50),
          importance: NotificationImportance.High,
          playSound: false,
          enableVibration: true,
        ),
      ],
      debug: false,
    );

    await _awesome.setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );
  }

  static Future<void> _onActionReceivedMethod(ReceivedAction action) async {}

  static String _effectiveChannelKey(String? sound) {
    final choice = SettingsService.getAlarmChoiceSync();
    switch (choice) {
      case AlarmChoice.system:
        return SettingsService.channelKeyForChoice(AlarmChoice.system);
      case AlarmChoice.custom:
        return SettingsService.channelKeyForChoice(AlarmChoice.custom);
      case AlarmChoice.vibrate:
        return SettingsService.channelKeyForChoice(AlarmChoice.vibrate);
    }
  }

  static Future<void> showNow() async {
    final key = _effectiveChannelKey(null);
    await _awesome.createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: key,
        title: 'Teste',
        body: 'Notificação imediata',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> timerIn10s() async {
    final key = _effectiveChannelKey(null);
    await _awesome.createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: key,
        title: 'Teste',
        body: 'Agendada para ~10s',
      ),
      schedule: NotificationCalendar.fromDate(
        date: DateTime.now().add(const Duration(seconds: 10)),
      ),
    );
  }

  static Future<void> timerExactIn15s() async {
    final key = _effectiveChannelKey(null);
    await _awesome.createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        channelKey: key,
        title: 'Teste',
        body: 'Agendada exata para ~15s',
      ),
      schedule: NotificationCalendar.fromDate(
        date: DateTime.now().add(const Duration(seconds: 15)),
        preciseAlarm: true,
        allowWhileIdle: true,
      ),
    );
  }

  static Future<void> previewSelectedSound() async {
    await showNow();
  }

  static Future<void> openNotificationSettings(String packageName) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'openNotificationSettings',
        {'package': packageName},
      );
    } catch (_) {
      try {
        await _awesome.showNotificationConfigPage();
      } catch (_) {}
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  static Future<void> scheduleSeries({
    required int baseId,
    required DateTime firstWhen,
    required String title,
    required String body,
    required String sound,
    required Duration repeatEvery,
    required int repeatCount,
    String? payload,
  }) async {
    final channelKey = _effectiveChannelKey(sound);

    for (int i = 0; i < repeatCount; i++) {
      final when = firstWhen.add(
        Duration(minutes: repeatEvery.inMinutes * i),
      );
      final id = baseId + i;

      await _awesome.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey,
          title: title,
          body: body,
          payload: payload == null ? null : {'payload': payload},
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(
          date: when,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );
    }
  }

  static Future<void> cancelSeries(int baseId, int repeatCount) async {
    for (int i = 0; i < repeatCount; i++) {
      await _awesome.cancel(baseId + i);
    }
  }

  static Future<void> cancelAllForMed(
      int medId, {
        String? medName,
        int maxPerMed = 64,
      }) async {
    final baseId = medId * 1000;
    for (int i = 0; i < maxPerMed; i++) {
      await _awesome.cancel(baseId + i);
    }
  }

  static Future<void> cancelSeriesForMedication(int medId) async {
    await cancelSeries(medId * 1000, 12);
  }

  static Future<void> rescheduleAllAfterSoundChange({
    required List<Map<String, Object?>> meds,
    required Duration Function(Map<String, Object?> m) intervalFn,
    required DateTime Function(Map<String, Object?> m) nextFn,
  }) async {
    await init();

    for (final m in meds) {
      final id = m['id'] as int?;
      if (id == null) continue;

      final archived = (m['archived'] as int?) == 1;
      final enabled = (m['enabled'] as int?) == 1;
      if (archived || !enabled) {
        await cancelAllForMed(id, maxPerMed: 64);
        continue;
      }

      final name = (m['name'] as String?) ?? 'Remédio';
      final interval = intervalFn(m);
      final next = nextFn(m);

      await scheduleSeries(
        baseId: id * 1000,
        firstWhen: next.isAfter(DateTime.now())
            ? next
            : DateTime.now().add(const Duration(seconds: 5)),
        title: 'Hora do remédio',
        body: name,
        sound: (m['sound'] as String?) ?? 'alert',
        repeatEvery: interval,
        repeatCount: 12,
        payload: 'med:$id',
      );
    }
  }
}
