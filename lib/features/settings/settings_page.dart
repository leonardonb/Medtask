import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:get/get.dart';
import '../../core/settings_service.dart';
import '../../core/notification_service.dart';
import '../../viewmodels/med_list_viewmodel.dart';
import '../../core/app_settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AlarmChoice? _choice;
  bool _allowed = false;
  bool _loading = true;
  late AppSettingsController _app;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<AppSettingsController>()) {
      _app = Get.put(AppSettingsController(), permanent: true);
      _app.init();
    } else {
      _app = Get.find<AppSettingsController>();
    }
    _load();
  }

  Future<void> _load() async {
    await NotificationService.init();
    final c = await SettingsService.getAlarmChoice();
    final ok = await AwesomeNotifications().isNotificationAllowed();
    setState(() {
      _choice = c;
      _allowed = ok;
      _loading = false;
    });
  }

  Future<void> _askPermission() async {
    final ok = await AwesomeNotifications().isNotificationAllowed();
    if (!ok) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    final ok2 = await AwesomeNotifications().isNotificationAllowed();
    setState(() => _allowed = ok2);
    if (!ok2 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão negada. Abra as configurações do app.')),
      );
    }
  }

  Future<void> _openAppNotifSettings() async {
    await NotificationService.openNotificationSettings('com.example.medtask');
  }

  Future<void> _set(AlarmChoice c) async {
    setState(() => _choice = c);
    await SettingsService.setAlarmChoice(c);
    final hasVm = Get.isRegistered<MedListViewModel>();
    if (hasVm) {
      final vm = Get.find<MedListViewModel>();
      await vm.rescheduleAllAfterSoundChange();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferência aplicada para notificações futuras')),
    );
  }

  Future<void> _preview() async {
    if (_choice == null) return;
    if (!_allowed) {
      await _askPermission();
      if (!_allowed) return;
    }
    await NotificationService.previewSelectedSound();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _choice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(_allowed ? Icons.notifications_active : Icons.notifications_off),
            title: Text(_allowed ? 'Notificações permitidas' : 'Notificações bloqueadas'),
            subtitle: const Text('Android 13+ exige permissão em tempo de execução'),
            trailing: _allowed
                ? null
                : FilledButton(
              onPressed: _askPermission,
              child: const Text('Permitir'),
            ),
            onTap: _allowed ? null : _askPermission,
          ),
          if (!_allowed)
            TextButton.icon(
              onPressed: _openAppNotifSettings,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir configurações do app'),
            ),
          const Divider(height: 32),
          const Text('Aparência', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Obx(() {
            final mode = _app.themeMode.value;
            return SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {mode},
              onSelectionChanged: (s) => _app.setThemeMode(s.first),
            );
          }),
          const Divider(height: 32),
          const Text('Som das notificações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          RadioListTile<AlarmChoice>(
            title: const Text('Som do sistema'),
            value: AlarmChoice.system,
            groupValue: _choice,
            onChanged: (c) => _set(c!),
          ),
          RadioListTile<AlarmChoice>(
            title: const Text('Som do app (alarme.mp3)'),
            value: AlarmChoice.custom,
            groupValue: _choice,
            onChanged: (c) => _set(c!),
          ),
          RadioListTile<AlarmChoice>(
            title: const Text('Apenas vibrar'),
            value: AlarmChoice.vibrate,
            groupValue: _choice,
            onChanged: (c) => _set(c!),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Ouvir prévia'),
          ),
          const Divider(height: 32),
          const Text('Testes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.notification_important),
            title: const Text('Notificação imediata'),
            subtitle: const Text('showNow'),
            onTap: () async {
              await NotificationService.showNow();
            },
            trailing: const Icon(Icons.play_arrow),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Agendar em 10 segundos'),
            subtitle: const Text('timerIn10s'),
            onTap: () async {
              await NotificationService.timerIn10s();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Agendado para ~10s')),
              );
            },
            trailing: const Icon(Icons.play_arrow),
          ),
          ListTile(
            leading: const Icon(Icons.alarm_on),
            title: const Text('Agendar exato em 15 segundos'),
            subtitle: const Text('timerExactIn15s'),
            onTap: () async {
              await NotificationService.timerExactIn15s();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Agendado exato para ~15s')),
              );
            },
            trailing: const Icon(Icons.play_arrow),
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Abrir otimização de bateria'),
            subtitle: const Text('openBatteryOptimizationSettings'),
            onTap: () async {
              await NotificationService.openBatteryOptimizationSettings();
            },
            trailing: const Icon(Icons.open_in_new),
          ),
        ],
      ),
    );
  }
}
