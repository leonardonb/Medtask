import 'package:flutter/material.dart';
import '../../data/repositories/dose_repository.dart';
import '../../models/dose_log.dart';
import '../../utils/dt.dart';

class DoseHistoryPage extends StatefulWidget {
  const DoseHistoryPage({super.key});

  @override
  State<DoseHistoryPage> createState() => _DoseHistoryPageState();
}

class _DoseHistoryPageState extends State<DoseHistoryPage> {
  final DoseRepository _repo = DoseRepository();
  bool _loading = true;
  List<DoseEventItem> _items = const [];
  int _limit = 300;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.listRecentWithMedication(limit: _limit);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  IconData _icon(DoseStatus s) {
    switch (s) {
      case DoseStatus.taken:
        return Icons.check_circle_rounded;
      case DoseStatus.skipped:
        return Icons.fast_forward_rounded;
      case DoseStatus.missed:
        return Icons.cancel_rounded;
    }
  }

  String _label(DoseStatus s) {
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
        return cs.tertiary; // “verde” do tema (varia por tema)
      case DoseStatus.skipped:
        return cs.primary; // azul/primária
      case DoseStatus.missed:
        return cs.error; // vermelho
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
        _label(s),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _statusOnBgColor(context, s),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<int>(
            tooltip: 'Limite',
            onSelected: (v) async {
              _limit = v;
              await _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 100, child: Text('100 registros')),
              PopupMenuItem(value: 300, child: Text('300 registros')),
              PopupMenuItem(value: 1000, child: Text('1000 registros')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
        child: Text(
          'Nenhuma dose registrada ainda.',
          style: theme.textTheme.bodyLarge,
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final it = _items[i];
            final e = it.event;

            final title = it.medicationName;
            final when = dtFmt(e.scheduledAt);

            final iconColor = _statusColor(context, e.status);

            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusBgColor(context, e.status),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _icon(e.status),
                  color: iconColor,
                ),
              ),
              title: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        when,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    _statusChip(context, e.status),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
