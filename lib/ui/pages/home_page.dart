import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../viewmodels/med_list_viewmodel.dart';
import '../../models/medication.dart';
import 'edit_med_page.dart';
import '../../features/settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _ticker;
  final _vm = Get.put(MedListViewModel(), permanent: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _vm.init();
      if (mounted) setState(() {});
    });
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
    final next = vm.nextGrid(m);
    final diff = next.difference(DateTime.now());
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff.isNegative) return '00:00:00';
    final h = diff.inHours;
    final mm = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    return '${two(h)}:${two(mm)}:${two(s)}';
  }

  String _formatNext(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _showSnackNext(int id, String prefix) async {
    final vm = _vm;
    final updated = vm.meds.firstWhereOrNull((e) => e.id == id);
    if (updated == null) return;
    final next = vm.nextGrid(updated);
    String two(int n) => n.toString().padLeft(2, '0');
    final txt = '$prefix ${two(next.hour)}:${two(next.minute)}';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Remédios'),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings),
            onPressed: () => Get.to(() => const SettingsPage()),
          ),
        ],
      ),
      body: Obx(() {
        if (vm.meds.isEmpty) {
          return const Center(child: Text('Nenhum remédio. Toque + para adicionar.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: vm.meds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final m = vm.meds[i];
            final next = vm.nextGrid(m);
            final nextStr = _formatNext(next);
            final cd = _countdown(m, vm);

            return Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  nextStr,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                cd,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: m.id == null
                                ? null
                                : () async {
                              await vm.markTaken(m.id!);
                              await _showSnackNext(m.id!, 'Próximo às');
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Tomei agora'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: m.id == null
                                ? null
                                : () async {
                              await vm.rewindPrevious(m.id!);
                              await _showSnackNext(m.id!, 'Reagendado para');
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Marcado como atrasado')),
                              );
                            },
                            icon: const Icon(Icons.schedule, size: 18),
                            label: const Text('Adiar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: m.id == null
                                ? null
                                : () async {
                              await vm.skipNext(m.id!);
                              await _showSnackNext(m.id!, 'Pulou para');
                            },
                            icon: const Icon(Icons.skip_next, size: 18),
                            label: const Text('Pular'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Get.to(() => EditMedPage(existing: m)),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Editar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: m.id == null
                                ? null
                                : () async {
                              await vm.toggleEnabled(m.id!, !m.enabled);
                              final msg = m.enabled ? 'Notificações OFF' : 'Notificações ON';
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            },
                            icon: Icon(m.enabled ? Icons.notifications_active : Icons.notifications_off, size: 18),
                            label: Text(m.enabled ? 'ON' : 'OFF'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              side: BorderSide(color: Theme.of(context).colorScheme.error),
                            ),
                            onPressed: m.id == null
                                ? null
                                : () async {
                              await vm.remove(m.id!);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Remédio excluído')),
                              );
                            },
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Excluir'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const EditMedPage()),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }
}
