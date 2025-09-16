import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

enum AlarmChoice { system, custom, vibrate }

class SettingsService {
  static const _kAlarmChoiceKey = 'alarm_choice';
  static const _kThemeModeKey = 'theme_mode';

  static Future<AlarmChoice> getAlarmChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAlarmChoiceKey);
    switch (raw) {
      case 'custom':
        return AlarmChoice.custom;
      case 'vibrate':
        return AlarmChoice.vibrate;
      case 'system':
      default:
        return AlarmChoice.system;
    }
  }

  static Future<void> setAlarmChoice(AlarmChoice c) async {
    final prefs = await SharedPreferences.getInstance();
    final v = switch (c) {
      AlarmChoice.system => 'system',
      AlarmChoice.custom => 'custom',
      AlarmChoice.vibrate => 'vibrate',
    };
    await prefs.setString(_kAlarmChoiceKey, v);
  }

  static String channelKeyForChoice(AlarmChoice c) {
    switch (c) {
      case AlarmChoice.system:
        return 'system';
      case AlarmChoice.custom:
        return 'custom';
      case AlarmChoice.vibrate:
        return 'vibrate';
    }
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey) ?? 'system';
    if (raw == 'light') return ThemeMode.light;
    if (raw == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    await prefs.setString(_kThemeModeKey, raw);
  }
}
