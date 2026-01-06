import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../viewmodels/med_list_viewmodel.dart';
import '../../models/medication.dart';
import '../../models/dose_log.dart';
import '../../data/repositories/dose_repository.dart';

import 'edit_med_page.dart';
import '../../features/settings/settings_page.dart';
import 'archived_meds_page.dart';
import 'dose_history_page.dart';
import 'about/about_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final MedListViewModel _vm;
  final DoseRepository _doseRepo = DoseRepository();

  Timer? _minuteRefresh;
  Timer? _rxNudge;

  late DateTime _selectedDate;

  final Map<String, DoseStatus> _statusCache = {};
  bool _statusLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _vm = Get.isRegistered<MedListViewModel>()
        ? Get.find<MedListViewModel>()
        : Get.put(MedListViewModel(), permanent: true);

    _selectedDate = _dateOnly(DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _vm.init();
      await _prefetchStatusesForSelectedDay();
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

  Future<void> _refresh() async {
    await _vm.reload();
    await _prefetchStatusesForSelectedDay();
    if (mounted) setState(() {});
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _key(int medId, DateTime scheduledAt) =>
      '$medId|${scheduledAt.millisecondsSinceEpoch}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTimeRange _dayRange(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return DateTimeRange(start: start, end: end);
  }

  List<DateTime> _occurrencesOnDate(Medication m, DateTime day) {
    final range = _dayRange(day);
    final start = range.start;
    final end = range.end;

    final intervalMin = m.intervalMinutes;
    if (intervalMin <= 0) return const [];

    final step = Duration(minutes: intervalMin);

    // Se o medicamento só começa depois do final do dia, não tem ocorrências.
    final first = m.firstDose;
    if (first.isAfter(end)) return const [];

    // Encontrar a primeira ocorrência >= start
    DateTime t = first;

    if (t.isBefore(start)) {
      final diffMin = start.difference(t).inMinutes;
      final k = diffMin ~/ step.inMinutes;
      t = t.add(Duration(minutes: step.inMinutes * k));
      while (t.isBefore(start)) {
        t = t.add(step);
      }
    }

    // Coletar ocorrências até end (cap defensivo)
    final out = <DateTime>[];
    int guard = 0;
    while (t.isBefore(end) && guard < 200) {
      out.add(t);
      t = t.add(step);
      guard++;
    }
    return out;
  }

  Future<void> _prefetchStatusesForSelectedDay() async {
    if (_statusLoading) return;
    _statusLoading = true;

    try {
      final meds = _vm.meds.toList();
      final now = DateTime.now();
      final sel = _selectedDate;

      for (final m in meds) {
        if (m.id == null) continue;

        final occs = _occurrencesOnDate(m, sel);
        for (final occ in occs) {
          // você quer ícone padrão para futura, então não precisa status para futuro
          if (occ.isAfter(now)) continue;

          final k = _key(m.id!, occ);
          if (_statusCache.containsKey(k)) continue;

          final st = await _doseRepo.getEventStatus(m.id!, occ);
          if (st != null) {
            _statusCache[k] = st;
          }
        }
      }
    } finally {
      _statusLoading = false;
    }
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditMedPage()),
    );
    await _refresh();
  }

  Future<void> _openEdit(Medication m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditMedPage(existing: m)),
    );
    await _refresh();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openArchived() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArchivedMedsPage()),
    );
  }

  void _openInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutPage()),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DoseHistoryPage()),
    );
  }

  Future<bool> _confirm(
      BuildContext context, {
        required String title,
        required String message,
      }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  List<Widget> _buildTopActions(double w) {
    if (w >= 560) {
      return [
        IconButton(
          tooltip: 'Adicionar',
          icon: const Icon(Icons.add_circle_rounded),
          onPressed: _openAdd,
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            switch (v) {
              case 'archived':
                _openArchived();
                break;
              case 'history':
                _openHistory();
                break;
              case 'info':
                _openInfo();
                break;
              case 'settings':
                _openSettings();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'archived',
              child: ListTile(
                leading: Icon(Icons.archive_outlined),
                title: Text('Arquivados'),
              ),
            ),
            PopupMenuItem(
              value: 'history',
              child: ListTile(
                leading: Icon(Icons.history_rounded),
                title: Text('Histórico'),
              ),
            ),
            PopupMenuItem(
              value: 'info',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Informações'),
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Configurações'),
              ),
            ),
          ],
        ),
      ];
    }

    return [
      IconButton(
        tooltip: 'Adicionar',
        icon: const Icon(Icons.add_circle_rounded),
        onPressed: _openAdd,
      ),
      IconButton(
        tooltip: 'Arquivados',
        icon: const Icon(Icons.archive_outlined),
        onPressed: _openArchived,
      ),
      IconButton(
        tooltip: 'Histórico',
        icon: const Icon(Icons.history_rounded),
        onPressed: _openHistory,
      ),
      IconButton(
        tooltip: 'Informações',
        icon: const Icon(Icons.info_outline),
        onPressed: _openInfo,
      ),
      IconButton(
        tooltip: 'Configurações',
        icon: const Icon(Icons.settings),
        onPressed: _openSettings,
      ),
    ];
  }

  IconData _statusIcon(DoseStatus s) {
    switch (s) {
      case DoseStatus.taken:
        return Icons.check_circle_rounded;
      case DoseStatus.skipped:
        return Icons.fast_forward_rounded;
      case DoseStatus.missed:
        return Icons.cancel_rounded;
    }
  }

  String _statusLabel(DoseStatus s) {
    switch (s) {
      case DoseStatus.taken:
        return 'Tomada';
      case DoseStatus.skipped:
        return 'Pulada';
      case DoseStatus.missed:
        return 'Esquecida';
    }
  }

  Color _statusColor(BuildContext context, DoseStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case DoseStatus.taken:
        return cs.tertiary;
      case DoseStatus.skipped:
        return cs.primary;
      case DoseStatus.missed:
        return cs.error;
    }
  }

  Color _statusBgColor(BuildContext context, DoseStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case DoseStatus.taken:
        return cs.tertiaryContainer;
      case DoseStatus.skipped:
        return cs.primaryContainer;
      case DoseStatus.missed:
        return cs.errorContainer;
    }
  }

  Color _statusOnBgColor(BuildContext context, DoseStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case DoseStatus.taken:
        return cs.onTertiaryContainer;
      case DoseStatus.skipped:
        return cs.onPrimaryContainer;
      case DoseStatus.missed:
        return cs.onErrorContainer;
    }
  }

  Widget _statusChip(BuildContext context, DoseStatus s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusBgColor(context, s),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(s),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _statusOnBgColor(context, s),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedTask'),
        actions: _buildTopActions(w),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: _DateStrip(
              selected: _selectedDate,
              onSelect: (d) async {
                setState(() => _selectedDate = d);
                await _prefetchStatusesForSelectedDay();
                if (mounted) setState(() {});
              },
              dateOnly: _dateOnly,
            ),
          ),
          Expanded(
            child: Obx(() {
              final meds = _vm.meds.toList();

              // lista achatada de doses do dia: (med, occ)
              final slots = <_DoseSlot>[];
              for (final m in meds) {
                final occs = _occurrencesOnDate(m, _selectedDate);
                for (final occ in occs) {
                  slots.add(_DoseSlot(med: m, scheduledAt: occ));
                }
              }

              slots.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

              if (slots.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Nenhuma dose para este dia.\nToque em Adicionar para cadastrar um remédio.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: slots.length,
                itemBuilder: (_, i) {
                  final slot = slots[i];
                  final m = slot.med;
                  final occ = slot.scheduledAt;

                  final isFuture = occ.isAfter(now);
                  DoseStatus? status;

                  if (!isFuture && m.id != null) {
                    status = _statusCache[_key(m.id!, occ)];
                  }

                  final isToday = _sameDay(_selectedDate, _dateOnly(now));
                  final overdue = isToday && !isFuture && status == null;

                  IconData leadingIcon = Icons.medication_rounded;
                  Color leadingBg = theme.colorScheme.primaryContainer;
                  Color leadingFg = theme.colorScheme.onPrimaryContainer;

                  if (status != null) {
                    leadingIcon = _statusIcon(status);
                    leadingBg = _statusBgColor(context, status);
                    leadingFg = _statusColor(context, status);
                  } else if (overdue) {
                    leadingIcon = Icons.priority_high_rounded;
                    leadingBg = theme.colorScheme.errorContainer;
                    leadingFg = theme.colorScheme.onErrorContainer;
                  } else {
                    // futuro: ícone padrão
                    leadingIcon = Icons.medication_rounded;
                    leadingBg = theme.colorScheme.primaryContainer;
                    leadingFg = theme.colorScheme.onPrimaryContainer;
                  }

                  return Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openEdit(m),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: leadingBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(leadingIcon, color: leadingFg),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Dose: ${_hhmm(occ)} • Intervalo: ${m.intervalMinutes} min',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                      if (status != null) _statusChip(context, status),
                                      if (overdue) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Atrasado',
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              color: theme.colorScheme.onErrorContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Ações',
                              icon: const Icon(Icons.more_horiz_rounded),
                              onPressed: () => _openActions(m),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _openActions(Medication m) {
    final vm = _vm;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final filledStyle = FilledButton.styleFrom(minimumSize: const Size.fromHeight(46));
        final outlinedStyle = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46));
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.name,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FilledButton.icon(
                    onPressed: m.id == null
                        ? null
                        : () async {
                      final ok = await _confirm(
                        context,
                        title: 'Confirmar',
                        message: 'Marcar a dose de "${m.name}" como tomada agora?',
                      );
                      if (!ok) return;
                      await vm.markTaken(m.id!);
                      _statusCache.clear();
                      await _refresh();
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Tomei agora'),
                    style: filledStyle,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: m.id == null
                        ? null
                        : () async {
                      final ok = await _confirm(
                        context,
                        title: 'Confirmar',
                        message: 'Marcar a dose de "${m.name}" como esquecida?',
                      );
                      if (!ok) return;
                      await vm.markMissed(m.id!);
                      _statusCache.clear();
                      await _refresh();
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.report_gmailerrorred_rounded),
                    label: const Text('Esqueci'),
                    style: outlinedStyle,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: m.id == null
                        ? null
                        : () async {
                      final ok = await _confirm(
                        context,
                        title: 'Confirmar',
                        message: 'Pular a próxima dose de "${m.name}"?',
                      );
                      if (!ok) return;
                      await vm.skipNext(m.id!);
                      _statusCache.clear();
                      await _refresh();
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.fast_forward_rounded),
                    label: const Text('Pular'),
                    style: outlinedStyle,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _openEdit(m);
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar'),
                    style: outlinedStyle,
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

class _DoseSlot {
  final Medication med;
  final DateTime scheduledAt;
  const _DoseSlot({required this.med, required this.scheduledAt});
}

class _DateStrip extends StatelessWidget {
  final DateTime selected;
  final void Function(DateTime) onSelect;
  final DateTime Function(DateTime) dateOnly;

  const _DateStrip({
    required this.selected,
    required this.onSelect,
    required this.dateOnly,
  });

  String _dayLabel(DateTime d) {
    const w = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final wd = w[(d.weekday - 1) % 7];
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$wd $dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    final now = dateOnly(DateTime.now());
    final days = List.generate(14, (i) => now.add(Duration(days: i - 6)));
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = days[i];
          final isSel = d.year == selected.year && d.month == selected.month && d.day == selected.day;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isSel
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
              ),
              child: Center(
                child: Text(
                  _dayLabel(d),
                  style: TextStyle(
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
