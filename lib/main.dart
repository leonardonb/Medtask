import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ui/pages/home_page.dart' as pages;
import 'viewmodels/med_list_viewmodel.dart';
import 'core/notification_service.dart' as notif;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await notif.NotificationService.init(defaultRawSound: 'alert');

  final listVm = Get.put(MedListViewModel(), permanent: true);
  await listVm.init();

  runApp(const MedApp());
}

class MedApp extends StatelessWidget {
  const MedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Remédios',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const pages.HomePage(),
    );
  }
}
