import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AlarmChoice { system, custom, vibrate }

class SettingsService {
  static SharedPreferences? _prefs;

  static const _kAlarmChoice = 'alarm_choice';
  static const _kThemeMode = 'theme_mode';

  static AlarmChoice _alarmChoiceCache = AlarmChoice.system;
  static ThemeMode _themeModeCache = ThemeMode.system;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    final alarmStr = _prefs!.getString(_kAlarmChoice);
    _alarmChoiceCache = _alarmChoiceFromString(alarmStr) ?? AlarmChoice.system;

    final themeStr = _prefs!.getString(_kThemeMode);
    _themeModeCache = _themeModeFromString(themeStr) ?? ThemeMode.system;
  }

  static AlarmChoice getAlarmChoiceSync() => _alarmChoiceCache;

  static Future<AlarmChoice> getAlarmChoice() async {
    if (_prefs == null) await init();
    final s = _prefs!.getString(_kAlarmChoice);
    _alarmChoiceCache = _alarmChoiceFromString(s) ?? AlarmChoice.system;
    return _alarmChoiceCache;
  }

  static Future<void> setAlarmChoice(AlarmChoice c) async {
    if (_prefs == null) await init();
    _alarmChoiceCache = c;
    await _prefs!.setString(_kAlarmChoice, _alarmChoiceToString(c));
  }

  static ThemeMode getThemeModeSync() => _themeModeCache;

  static Future<ThemeMode> getThemeMode() async {
    if (_prefs == null) await init();
    final s = _prefs!.getString(_kThemeMode);
    _themeModeCache = _themeModeFromString(s) ?? ThemeMode.system;
    return _themeModeCache;
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    if (_prefs == null) await init();
    _themeModeCache = m;
    await _prefs!.setString(_kThemeMode, _themeModeToString(m));
  }

  static String channelKeyForChoice(AlarmChoice c) {
    switch (c) {
      case AlarmChoice.system:
        return 'medtask_system';
      case AlarmChoice.custom:
        return 'medtask_custom';
      case AlarmChoice.vibrate:
        return 'medtask_vibrate';
    }
  }

  static AlarmChoice? _alarmChoiceFromString(String? s) {
    switch (s) {
      case 'system':
        return AlarmChoice.system;
      case 'custom':
        return AlarmChoice.custom;
      case 'vibrate':
        return AlarmChoice.vibrate;
      default:
        return null;
    }
  }

  static String _alarmChoiceToString(AlarmChoice c) {
    switch (c) {
      case AlarmChoice.system:
        return 'system';
      case AlarmChoice.custom:
        return 'custom';
      case AlarmChoice.vibrate:
        return 'vibrate';
    }
  }

  static ThemeMode? _themeModeFromString(String? s) {
    switch (s) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  static String _themeModeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}
