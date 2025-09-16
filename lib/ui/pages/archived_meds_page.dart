import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/archive_service.dart';
import '../../viewmodels/med_list_viewmodel.dart';
import '../../models/medication.dart';
import '../../data/db/app_db.dart';
import '../../core/notification_helpers.dart';
import '../../core/notification_service.dart';
import 'edit_med_page.dart';

class ArchivedMedsPage extends StatefulWidget {
  const ArchivedMedsPage({super.key});

  @override
  State<ArchivedMedsPage> createState() => _ArchivedMedsPageState();
}

class _ArchivedMedsPageState extends State<ArchivedMedsPage> {
  final _svc = ArchiveService();
  List<ArchivedMed> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final data = await _svc.listArchived();
    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<Medication?> _resolveMedication(int id) async {
    if (Get.isRegistered<MedListViewModel>()) {
      final vm = Get.find<MedListViewModel>();
      try {
        return vm.meds.firstWhere((x) => x.id == id);
      } catch (_) {}
    }
    final db = await AppDb.instance;
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      return Medication.fromMap(rows.first);
    }
    return null;
  }

  Future<void> _openEditThenUnarchive(ArchivedMed a) async {
    final med = await _resolveMedication(a.id);
    if (!mounted) return;
    if (med == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir para edição.')));
      return;
    }
    final res = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => EditMedPage(existing: med, justUnarchived: true)),
    );
    if (!mounted) return;
    if (res == true) {
      await _svc.unarchive(a.id);
      if (Get.isRegistered<MedListViewModel>()) {
        await Get.find<MedListViewModel>().init();
      }
      await _reload();
      Navigator.of(context, rootNavigator: true).pop(true);
    } else {
      await _reload();
    }
  }

  Future<void> _delete(ArchivedMed a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir medicamento'),
        content: Text('Deseja excluir "${a.name}" permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await NotificationService.cancelSeries(a.id * 1000, 12);
    } catch (_) {}
    try {
      await NotificationHelpers.cancelAllForMed(a.id, maxPerMed: 64);
    } catch (_) {}

    try {
      final vm = Get.isRegistered<MedListViewModel>()
          ? Get.find<MedListViewModel>()
          : Get.put(MedListViewModel(), permanent: true);
      await vm.remove(a.id);
    } catch (_) {
      final db = await AppDb.instance;
      await db.delete('medications', where: 'id = ?', whereArgs: [a.id]);
    }

    try {
      await _svc.unarchive(a.id);
    } catch (_) {}

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicamentos arquivados')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('Nenhum medicamento arquivado.'))
          : ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = _items[i];
          final subtitle = m.archivedAt == null ? 'Arquivado' : 'Arquivado em: ${_fmt(m.archivedAt!)}';
          return ListTile(
            title: Text(m.name),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Desarquivar e editar',
                  icon: const Icon(Icons.unarchive),
                  onPressed: () => _openEditThenUnarchive(m),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(m),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
