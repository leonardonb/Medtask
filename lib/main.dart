import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/notification_service.dart' as notif;
import 'ui/pages/home_page.dart';
import 'features/settings/settings_page.dart';
import 'core/app_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notif.NotificationService.init();
  final app = Get.put(AppSettingsController(), permanent: true);
  await app.init();
  runApp(const MedApp());
}

class MedApp extends StatelessWidget {
  const MedApp({super.key});
  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppSettingsController>();
    return Obx(() {
      return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MedTask',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
        themeMode: app.themeMode.value,
        getPages: [
          GetPage(name: '/settings', page: () => const SettingsPage()),
        ],
        home: const HomePage(),
      );
    });
  }
}
