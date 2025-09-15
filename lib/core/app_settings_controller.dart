import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'settings_service.dart';

class AppSettingsController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  Future<void> init() async {
    themeMode.value = await SettingsService.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode.value = m;
    await SettingsService.setThemeMode(m);
  }
}
