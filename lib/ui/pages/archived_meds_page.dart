import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/archive_service.dart';
import '../../viewmodels/med_list_viewmodel.dart';
import '../../models/medication.dart';
import '../../data/db/app_db.dart';
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

  Future<void> _unarchive(ArchivedMed m) async {
    await _svc.unarchive(m.id);
    if (Get.isRegistered<MedListViewModel>()) {
      await Get.find<MedListViewModel>().init();
    }
    final db = await AppDb.instance;
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [m.id], limit: 1);
    if (rows.isNotEmpty) {
      final med = Medication.fromMap(rows.first);
      if (!mounted) return;
      await Get.off(() => EditMedPage(existing: med, justUnarchived: true));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
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
            trailing: IconButton(
              icon: const Icon(Icons.unarchive),
              onPressed: () => _unarchive(m),
              tooltip: 'Desarquivar',
            ),
          );
        },
      ),
    );
  }
}
