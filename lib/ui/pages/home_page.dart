import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../viewmodels/med_list_viewmodel.dart';
import '../../models/medication.dart';
import 'edit_med_page.dart';
import '../../features/settings/settings_page.dart';
import 'archived_meds_page.dart';
import 'about/about_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final MedListViewModel _vm;
  final Stream<DateTime> _tick =
  Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asBroadcastStream();

  Timer? _minuteRefresh;
  Timer? _rxNudge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _vm = Get.isRegistered<MedListViewModel>()
        ? Get.find<MedListViewModel>()
        : Get.put(MedListViewModel(), permanent: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _vm.init();
      if (mounted) setState(() {});
    });

    _minuteRefresh = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _refresh();
    });

    _rxNudge = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _vm.meds.refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteRefresh?.cancel();
    _rxNudge?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  String _formatNext(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _refresh() async {
    await _vm.init();
    if (mounted) {
      _vm.meds.refresh();
      setState(() {});
    }
  }

  Future<void> _openAdd() async {
    final r = await Get.to(() => const EditMedPage());
    if (r == true) {
      await _refresh();
    } else if (r is Map && r['refresh'] == true) {
      if (r['ensureEnabledId'] is int && r['shouldBeEnabled'] == true) {
        await _vm.toggleEnabled(r['ensureEnabledId'] as int, true);
      }
      await _refresh();
    }
  }

  Future<void> _openArchived() async {
    final r = await Get.to(() => const ArchivedMedsPage());
    if (r == true) {
      await _refresh();
    } else if (r is Map && r['refresh'] == true) {
      if (r['ensureEnabledId'] is int && r['shouldBeEnabled'] == true) {
        await _vm.toggleEnabled(r['ensureEnabledId'] as int, true);
      }
      await _refresh();
    }
  }

  void _openInfo() => Get.to(() => const AboutPage());
  void _openSettings() => Get.to(() => const SettingsPage());

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      title: const Text('Meus Remédios', overflow: TextOverflow.ellipsis, softWrap: false),
      centerTitle: false,
      titleSpacing: 8,
      actions: _buildActions(context),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withOpacity(0.16),
              cs.secondary.withOpacity(0.10),
              cs.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    if (w < 430) {
      return [
        IconButton(tooltip: 'Adicionar', icon: const Icon(Icons.add_circle_rounded), onPressed: _openAdd),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            switch (v) {
              case 'archived': _openArchived(); break;
              case 'info': _openInfo(); break;
              case 'settings': _openSettings(); break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'archived', child: ListTile(leading: Icon(Icons.archive_outlined), title: Text('Arquivados'))),
            PopupMenuItem(value: 'info', child: ListTile(leading: Icon(Icons.info_outline), title: Text('Informações'))),
            PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings), title: Text('Configurações'))),
          ],
        ),
      ];
    }

    if (w < 560) {
      return [
        IconButton(tooltip: 'Adicionar', icon: const Icon(Icons.add_circle_rounded), onPressed: _openAdd),
        IconButton(tooltip: 'Arquivados', icon: const Icon(Icons.archive_outlined), onPressed: _openArchived),
        IconButton(tooltip: 'Informações', icon: const Icon(Icons.info_outline), onPressed: _openInfo),
        IconButton(tooltip: 'Configurações', icon: const Icon(Icons.settings), onPressed: _openSettings),
      ];
    }

    return [
      TextButton.icon(onPressed: _openAdd, icon: const Icon(Icons.add_circle_rounded), label: const Text('Adicionar')),
      IconButton(tooltip: 'Arquivados', icon: const Icon(Icons.archive_outlined), onPressed: _openArchived),
      IconButton(tooltip: 'Informações', icon: const Icon(Icons.info_outline), onPressed: _openInfo),
      IconButton(tooltip: 'Configurações', icon: const Icon(Icons.settings), onPressed: _openSettings),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, _) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Obx(() {
                  if (vm.meds.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      color: Theme.of(context).colorScheme.primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          Icon(Icons.medication_liquid_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          const Center(child: Text('Nenhum remédio. Toque + para adicionar.')),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: Theme.of(context).colorScheme.primary,
                    child: StreamBuilder<DateTime>(
                      stream: _tick,
                      initialData: DateTime.now(),
                      builder: (context, ts) {
                        final now = ts.data ?? DateTime.now();
                        final medsSorted = vm.meds.toList()
                          ..sort((a, b) {
                            final ta = vm.nextFireTime(a, now: now);
                            final tb = vm.nextFireTime(b, now: now);
                            return ta.compareTo(tb);
                          });

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: medsSorted.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final m = medsSorted[i];
                            final next = vm.nextGrid(m);
                            final nextStr = _formatNext(next);
                            final countdownWhen = vm.nextFireTime(m, now: now);
                            final isLate = !next.isAfter(now);
                            final cs = Theme.of(context).colorScheme;

                            final bg = isLate ? cs.errorContainer : cs.surface;
                            final border = isLate ? cs.error : cs.primary.withOpacity(0.25);
                            final titleColor = isLate ? cs.onErrorContainer : cs.onSurface;
                            final subColor = isLate ? cs.onErrorContainer : Theme.of(context).textTheme.bodyMedium?.color;

                            return _MedCard(
                              onTap: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  showDragHandle: true,
                                  isScrollControlled: true,
                                  builder: (_) => _ActionsSheet(m: m, vm: vm),
                                );
                              },
                              bg: bg,
                              border: border,
                              titleColor: titleColor,
                              subColor: subColor,
                              name: m.name,
                              nextStr: nextStr,
                              nextWhen: countdownWhen,
                              lateBadge: isLate,
                              enabled: m.enabled,
                            );
                          },
                        );
                      },
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MedCard extends StatelessWidget {
  final VoidCallback onTap;
  final Color bg;
  final Color border;
  final Color? titleColor;
  final Color? subColor;
  final String name;
  final String nextStr;
  final DateTime nextWhen;
  final bool lateBadge;
  final bool enabled;

  const _MedCard({
    required this.onTap,
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.subColor,
    required this.name,
    required this.nextStr,
    required this.nextWhen,
    required this.lateBadge,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primary.withOpacity(0.12),
                      foregroundColor: cs.primary,
                      child: const Icon(Icons.medication_rounded),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: enabled ? cs.primary : cs.outline,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          enabled ? 'ON' : 'OFF',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                          ),
                          if (lateBadge)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ATRASADO',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: cs.onError,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: cs.onSecondaryContainer),
                                const SizedBox(width: 6),
                                Text(
                                  nextStr,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: cs.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _CountdownBadge(nextWhen: nextWhen),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionsSheet extends StatelessWidget {
  final Medication m;
  final MedListViewModel vm;
  const _ActionsSheet({required this.m, required this.vm});

  Future<bool> _confirm(BuildContext context, {required String title, required String message, bool destructive = false}) async {
    final cs = Theme.of(context).colorScheme;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Não')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: destructive ? TextButton.styleFrom(foregroundColor: cs.error) : null,
            child: const Text('Sim'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    if (result != null) return result;
    final fallback = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive ? TextButton.styleFrom(foregroundColor: cs.error) : null,
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    return fallback == true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final minH = const Size.fromHeight(44);
    final deleteStyle = OutlinedButton.styleFrom(
      foregroundColor: cs.error,
      side: BorderSide(color: cs.error),
      minimumSize: minH,
    );
    final outlinedStyle = OutlinedButton.styleFrom(minimumSize: minH);
    final filledStyle = FilledButton.styleFrom(minimumSize: minH);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 38, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2))),
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                _CountdownBadge(nextWhen: vm.nextFireTime(m)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                FilledButton.icon(
                  onPressed: m.id == null
                      ? null
                      : () async {
                    final ok = await _confirm(context, title: 'Confirmar', message: 'Marcar a dose de "${m.name}" como tomada agora?');
                    if (!ok) return;
                    await vm.markTaken(m.id!);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Tomei agora'),
                  style: filledStyle,
                ),
                OutlinedButton.icon(
                  onPressed: m.id == null
                      ? null
                      : () async {
                    final ok = await _confirm(context, title: 'Confirmar', message: 'Pular a próxima dose de "${m.name}"?');
                    if (!ok) return;
                    await vm.skipNext(m.id!);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.fast_forward_rounded),
                  label: const Text('Pular'),
                  style: outlinedStyle,
                ),
                OutlinedButton.icon(
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
                    String two(int n) => n.toString().padLeft(2, '0');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adiado para ${two(when.hour)}:${two(when.minute)}')));
                      Navigator.of(context).maybePop();
                    }
                  },
                  icon: const Icon(Icons.schedule_send_rounded),
                  label: const Text('Adiar'),
                  style: outlinedStyle,
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await Get.to(() => EditMedPage(existing: m));
                    if (r == true) {
                      await vm.init();
                    } else if (r is Map && r['refresh'] == true) {
                      if (r['ensureEnabledId'] is int && r['shouldBeEnabled'] == true) {
                        await vm.toggleEnabled(r['ensureEnabledId'] as int, true);
                      }
                      await vm.init();
                    }
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                  style: outlinedStyle,
                ),
                OutlinedButton.icon(
                  onPressed: m.id == null
                      ? null
                      : () async {
                    await vm.toggleEnabled(m.id!, !m.enabled);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  icon: Icon(m.enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded),
                  label: Text(m.enabled ? 'ON' : 'OFF'),
                  style: outlinedStyle,
                ),
                OutlinedButton.icon(
                  onPressed: m.id == null
                      ? null
                      : () async {
                    final ok = await _confirm(
                      context,
                      title: 'Excluir',
                      message: 'Tem certeza que deseja excluir "${m.name}"? Esta ação não pode ser desfeita.',
                      destructive: true,
                    );
                    if (!ok) return;
                    await vm.remove(m.id!);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Excluir'),
                  style: deleteStyle,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
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
  final Stream<DateTime> _tick =
  Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asBroadcastStream();

  String _fmt(Duration diff) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff.isNegative) return '0d 0h 00m';
    final totalMinutes = ((diff.inSeconds + 59) ~/ 60);
    final d = totalMinutes ~/ (24 * 60);
    final h = (totalMinutes % (24 * 60)) ~/ 60;
    final m = totalMinutes % 60;
    return '${d}d ${h}h ${two(m)}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.25)),
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
              Icon(Icons.timer_rounded, size: 18, color: cs.onSecondaryContainer),
              const SizedBox(width: 6),
              Text(
                cd,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w800,
                  color: cs.onSecondaryContainer,
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
