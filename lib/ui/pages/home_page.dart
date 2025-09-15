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

  String _countdown(Medication m) {
    final diff = m.firstDose.difference(DateTime.now());
    String two(int n) => n.toString().padLeft(2, '0');
    final h = diff.inHours.abs();
    final mm = (diff.inMinutes % 60).abs();
    final s = (diff.inSeconds % 60).abs();
    final t = '${two(h)}:${two(mm)}:${two(s)}';
    if (diff.isNegative) return '-$t';
    return t;
  }

  bool _isLate(Medication m) => m.firstDose.isBefore(DateTime.now());

  String _formatNext(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _showSnackNextDateTime(DateTime when, String prefix) async {
    String two(int n) => n.toString().padLeft(2, '0');
    final txt = '$prefix ${two(when.hour)}:${two(when.minute)}';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
  }

  Future<void> _showSnackNextById(int id, String prefix) async {
    final updated = _vm.meds.firstWhereOrNull((e) => e.id == id);
    if (updated == null) return;
    await _showSnackNextDateTime(updated.firstDose, prefix);
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
            final nextStr = _formatNext(m.firstDose);
            final cd = _countdown(m);
            final late = _isLate(m);

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
                            color: late
                                ? Theme.of(context).colorScheme.error.withOpacity(0.10)
                                : Theme.of(context).colorScheme.primary.withOpacity(0.08),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(late ? Icons.warning_amber : Icons.timer, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                late ? 'Atrasado $cd' : cd,
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
                              await _showSnackNextById(m.id!, 'Próximo às');
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
                              final d = await showModalBottomSheet<Duration>(
                                context: context,
                                showDragHandle: true,
                                builder: (ctx) => const _PostponeSheet(),
                              );
                              if (d == null) return;
                              final when = await vm.postponeAlarm(m.id!, d);
                              if (when == null) return;
                              await _showSnackNextDateTime(when, 'Adiado para');
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
                              await _showSnackNextById(m.id!, 'Pulou para');
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

class _PostponeSheet extends StatelessWidget {
  const _PostponeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          Text('Adiar lembrete', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _DelayChip(label: '+1 min', duration: Duration(minutes: 1)),
              _DelayChip(label: '+5 min', duration: Duration(minutes: 5)),
              _DelayChip(label: '+10 min', duration: Duration(minutes: 10)),
              _DelayChip(label: '+30 min', duration: Duration(minutes: 30)),
              _DelayChip(label: '+60 min', duration: Duration(minutes: 60)),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DelayChip extends StatelessWidget {
  final String label;
  final Duration duration;
  const _DelayChip({required this.label, required this.duration});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.schedule, size: 18),
      onPressed: () => Navigator.of(context).pop(duration),
    );
  }
}
