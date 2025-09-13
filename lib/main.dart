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

  // Agendamento de teste único para ~20s a partir de agora
  await notif.NotificationService.scheduleOne(
    id: 9001,
    when: DateTime.now().add(const Duration(seconds: 20)),
    title: 'Ei, olha a hora do remédio…',
    body: 'Teste rápido: verifique se você recebe esta notificação.',
    sound: 'alert',
    exactIfPossible: true,
  );

  // Agendamento diário às 08:00
  await notif.NotificationService.scheduleDaily(
    id: 1001,
    hour: 8,
    minute: 0,
    title: 'Ei, olha a hora do remédio…',
    body: 'Cadê você? Lembra do remédio!!!',
    sound: 'alert',
    exactIfPossible: true,
  );

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
