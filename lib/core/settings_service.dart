import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

enum AlarmChoice { system, custom }

class SettingsService {
  static const _kAlarmChoiceKey = 'alarm_choice';
  static const _kThemeModeKey = 'theme_mode';

  static Future<AlarmChoice> getAlarmChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAlarmChoiceKey) ?? 'system';
    return raw == 'custom' ? AlarmChoice.custom : AlarmChoice.system;
  }

  static Future<void> setAlarmChoice(AlarmChoice c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAlarmChoiceKey, c == AlarmChoice.custom ? 'custom' : 'system');
  }

  static String channelKeyForChoice(AlarmChoice c) {
    return c == AlarmChoice.custom ? 'meds_channel_custom_v4' : 'meds_channel_system_v4';
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
