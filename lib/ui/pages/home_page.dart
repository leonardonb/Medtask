import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../viewmodels/med_list_viewmodel.dart';
import '../../models/medication.dart';
import 'edit_med_page.dart';
import '../../features/settings/settings_page.dart';
import 'archived_meds_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _vm = Get.put(MedListViewModel(), permanent: true);
  final Stream<DateTime> _tick = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asBroadcastStream();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _vm.init();
      if (mounted) setState(() {});
    });
  }

  String _formatNext(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _refresh() async {
    await _vm.init();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Remédios'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final r = await Get.to(() => const EditMedPage());
              if (r == true) {
                await _refresh();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
          IconButton(
            tooltip: 'Medicamentos arquivados',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () async {
              final r = await Get.to(() => const ArchivedMedsPage());
              if (r == true) {
                await _refresh();
              }
            },
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings),
            onPressed: () => Get.to(() => const SettingsPage()),
          ),
        ],
      ),
      body: Obx(() {
        if (vm.meds.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Nenhum remédio. Toque + para adicionar.')),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: vm.meds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final m = vm.meds[i];
              return StreamBuilder<DateTime>(
                stream: _tick,
                initialData: DateTime.now(),
                builder: (context, snap) {
                  final now = snap.data ?? DateTime.now();

                  final next = vm.nextGrid(m);
                  final nextStr = _formatNext(next);

                  int? attentionIndex;
                  Duration? bestDiff;
                  for (var j = 0; j < vm.meds.length; j++) {
                    final n = vm.nextGrid(vm.meds[j]);
                    if (n.isBefore(now)) continue;
                    final d = n.difference(now);
                    if (bestDiff == null || d < bestDiff) {
                      bestDiff = d;
                      attentionIndex = j;
                    }
                  }

                  final isLate = !next.isAfter(now);
                  final isAttention = !isLate && attentionIndex == i;

                  final cs = Theme.of(context).colorScheme;
                  final cardColor = isLate ? cs.errorContainer : cs.surfaceContainerHighest;
                  final titleColor = isLate ? cs.onErrorContainer : null;
                  final subColor = isLate ? cs.onErrorContainer : Theme.of(context).textTheme.bodyMedium?.color;

                  return Card(
                    elevation: isLate ? 1 : 0,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isLate ? BorderSide(color: cs.error, width: 2) : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                              if (isAttention)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cs.error.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ATENÇÃO',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: cs.error,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              if (isLate)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cs.error,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ATRASADO',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: cs.onError,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule, size: 18, color: subColor),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        nextStr,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: subColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _CountdownBadge(nextWhen: next),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: m.id == null ? null : () => vm.markTaken(m.id!),
                                  icon: const Icon(Icons.check),
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
                                    if (!mounted || when == null) return;
                                    String two(int n) => n.toString().padLeft(2, '0');
                                    final txt = 'Adiado para ${two(when.hour)}:${two(when.minute)}';
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
                                  },
                                  icon: const Icon(Icons.schedule_send),
                                  label: const Text('Adiar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: m.id == null ? null : () => vm.skipNext(m.id!),
                                  icon: const Icon(Icons.skip_next),
                                  label: const Text('Pular'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final r = await Get.to(() => EditMedPage(existing: m));
                                    if (r == true) {
                                      await _refresh();
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Editar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: m.id == null ? null : () => vm.toggleEnabled(m.id!, !m.enabled),
                                  icon: Icon(m.enabled ? Icons.notifications_active : Icons.notifications_off),
                                  label: Text(m.enabled ? 'ON' : 'OFF'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: m.id == null ? null : () => vm.remove(m.id!),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Excluir'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                                  ),
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
            },
          ),
        );
      }),
    );
  }
}

class _CountdownBadge extends StatefulWidget {
  final DateTime nextWhen;
  const _CountdownBadge({required this.nextWhen});

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  final Stream<DateTime> _tick = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asBroadcastStream();

  String _fmt(Duration diff) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff.isNegative) return '00:00:00';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.primary.withValues(alpha: 0.08),
      ),
      child: StreamBuilder<DateTime>(
        stream: _tick,
        initialData: DateTime.now(),
        builder: (context, snap) {
          final now = snap.data ?? DateTime.now();
          final cd = _fmt(widget.nextWhen.difference(now));
          return Row(
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
          );
        },
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
        children: const [
          SizedBox(height: 6),
          _SheetTitle(),
          SizedBox(height: 12),
          _DelayChips(),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle();
  @override
  Widget build(BuildContext context) {
    return Text('Adiar lembrete', style: Theme.of(context).textTheme.titleMedium);
  }
}

class _DelayChips extends StatelessWidget {
  const _DelayChips();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: const [
        _DelayChip(label: '+1 min', duration: Duration(minutes: 1)),
        _DelayChip(label: '+5 min', duration: Duration(minutes: 5)),
        _DelayChip(label: '+10 min', duration: Duration(minutes: 10)),
        _DelayChip(label: '+30 min', duration: Duration(minutes: 30)),
        _DelayChip(label: '+60 min', duration: Duration(minutes: 60)),
      ],
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
