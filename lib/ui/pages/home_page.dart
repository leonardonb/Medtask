import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../viewmodels/med_list_viewmodel.dart';
import '../../models/medication.dart';
import 'edit_med_page.dart';
import '../../core/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _countdown(Medication m, MedListViewModel vm) {
    final next = vm.nextPlanned(m);
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 'Atrasado';
    String two(int n) => n.toString().padLeft(2, '0');
    final h = diff.inHours;
    final mm = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    return '${two(h)}:${two(mm)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final vm = Get.find<MedListViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Remédios'),
        actions: [
          IconButton(
            tooltip: 'Imediato',
            icon: const Icon(Icons.notifications_active),
            onPressed: () async {
              final ok = await NotificationService.areNotificationsEnabled();
              if (!ok && context.mounted) {
                await NotificationService.openNotificationSettings('com.example.medtask');
              }
              await NotificationService.showNow();
            },
          ),
          IconButton(
            tooltip: '+10s (timer)',
            icon: const Icon(Icons.schedule),
            onPressed: () => NotificationService.timerIn10s(),
          ),
          IconButton(
            tooltip: '+15s (timer)',
            icon: const Icon(Icons.alarm_on),
            onPressed: () => NotificationService.timerExactIn15s(),
          ),
          IconButton(
            tooltip: 'Bateria',
            icon: const Icon(Icons.battery_saver),
            onPressed: () => NotificationService.openBatteryOptimizationSettings(),
          ),
        ],
      ),
      body: Obx(() {
        if (vm.meds.isEmpty) {
          return const Center(child: Text('Nenhum remédio. Toque + para adicionar.'));
        }
        return ListView.separated(
          itemCount: vm.meds.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final m = vm.meds[i];
            final next = vm.nextPlanned(m);
            String two(int n) => n.toString().padLeft(2, '0');
            final nextStr =
                '${two(next.day)}/${two(next.month)}/${next.year} ${two(next.hour)}:${two(next.minute)}';

            return ListTile(
              title: Text(m.name, overflow: TextOverflow.ellipsis),
              subtitle: Text('Em: ${_countdown(m, vm)}  •  Próx: $nextStr'),
              isThreeLine: true,
              trailing: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.58),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Tomei agora',
                        onPressed: m.id == null ? null : () => vm.markTaken(m.id!),
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                      PopupMenuButton<Duration>(
                        tooltip: 'Adiar',
                        icon: const Icon(Icons.schedule),
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: Duration(minutes: 1), child: Text('+1 min')),
                          PopupMenuItem(value: Duration(minutes: 5), child: Text('+5 min')),
                          PopupMenuItem(value: Duration(minutes: 10), child: Text('+10 min')),
                          PopupMenuItem(value: Duration(minutes: 30), child: Text('+30 min')),
                        ],
                        onSelected: (d) async {
                          final when = await vm.postpone(m.id!, d);
                          if (!mounted || when == null) return;
                          String two(int n) => n.toString().padLeft(2, '0');
                          final txt = 'Adiado para ${two(when.hour)}:${two(when.minute)}';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(txt)),
                          );
                        },
                      ),
                      Switch(
                        value: m.enabled,
                        onChanged: (v) => vm.toggleEnabled(m.id!, v),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit),
                        onPressed: () => Get.to(() => EditMedPage(existing: m)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Excluir',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => vm.remove(m.id!),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const EditMedPage()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
