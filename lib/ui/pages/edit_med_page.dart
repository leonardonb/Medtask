import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/medication.dart';
import '../../viewmodels/med_list_viewmodel.dart';
import '../../data/services/archive_service.dart';
import '../../core/notification_helpers.dart';
import '../../core/notification_service.dart';

class EditMedPage extends StatefulWidget {
  final Medication? existing;
  final bool justUnarchived;
  const EditMedPage({super.key, this.existing, this.justUnarchived = false});

  @override
  State<EditMedPage> createState() => _EditMedPageState();
}

class _EditMedPageState extends State<EditMedPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _minsCtrl;
  late DateTime _date;
  late TimeOfDay _time;
  late bool _enabled;
  DateTime? _autoDate;
  TimeOfDay? _autoTime;
  final _archiveSvc = ArchiveService();
  bool _archived = false;
  bool _archLoading = false;
  bool _justUnarchived = false;
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 1));
    final m = widget.existing;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    final totalMin = m?.intervalMinutes ?? 480;
    final h = totalMin ~/ 60;
    final mi = totalMin % 60;
    _hoursCtrl = TextEditingController(text: h.toString());
    _minsCtrl = TextEditingController(text: mi.toString());
    final first = m?.firstDose ?? now;
    _date = DateTime(first.year, first.month, first.day);
    _time = TimeOfDay(hour: first.hour, minute: first.minute);
    _enabled = m?.enabled ?? true;
    _justUnarchived = widget.justUnarchived;
    if (m?.autoArchiveAt != null) {
      _autoDate = DateTime(m!.autoArchiveAt!.year, m.autoArchiveAt!.month, m.autoArchiveAt!.day);
      _autoTime = TimeOfDay(hour: m.autoArchiveAt!.hour, minute: m.autoArchiveAt!.minute);
    }
    if (m?.id != null) {
      _loadArchived(m!.id!);
    }
  }

  Future<void> _loadArchived(int id) async {
    setState(() => _archLoading = true);
    final v = await _archiveSvc.isArchived(id);
    if (!mounted) return;
    setState(() {
      _archived = v;
      _archLoading = false;
      if (_archived) _enabled = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hoursCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickAutoDate() async {
    final base = _autoDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _autoDate = picked);
  }

  Future<void> _pickAutoTime() async {
    final base = _autoTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: base,
    );
    if (picked != null) setState(() => _autoTime = picked);
  }

  DateTime _combine(DateTime d, TimeOfDay t) {
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  DateTime? _combineAuto() {
    if (_autoDate == null || _autoTime == null) return null;
    return DateTime(_autoDate!.year, _autoDate!.month, _autoDate!.day, _autoTime!.hour, _autoTime!.minute);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final vm = Get.find<MedListViewModel>();
    final when = _combine(_date, _time);
    final h = int.parse(_hoursCtrl.text);
    final mi = int.parse(_minsCtrl.text);
    final minutes = h * 60 + mi;
    final current = widget.existing;
    final enabledFinal = _justUnarchived ? true : _enabled;
    final autoAt = _combineAuto();

    final med = current == null
        ? Medication(
      id: null,
      name: _nameCtrl.text.trim(),
      firstDose: when,
      intervalMinutes: minutes,
      enabled: enabledFinal,
      sound: 'alert',
      autoArchiveAt: autoAt,
    )
        : current.copyWith(
      name: _nameCtrl.text.trim(),
      firstDose: when,
      intervalMinutes: minutes,
      enabled: enabledFinal,
      autoArchiveAt: autoAt,
    );

    await vm.upsert(med);
    _saved = true;
    _justUnarchived = false;

    if (!mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop(true);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Get.back(result: true);
    }
  }

  Future<void> _toggleArchive() async {
    final m = widget.existing;
    if (m?.id == null) return;
    setState(() {
      _archLoading = true;
      if (!_archived) _enabled = false;
    });

    if (!_archived) {
      await _archiveSvc.archive(m!.id!);
      await NotificationService.cancelSeries(m.id! * 1000, 12);
      await NotificationHelpers.cancelAllForMed(m.id!, maxPerMed: 64);
      if (Get.isRegistered<MedListViewModel>()) {
        await Get.find<MedListViewModel>().init();
      }
      if (!mounted) return;
      _archived = true;
      _archLoading = false;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop(true);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Get.back(result: true);
      }
      return;
    } else {
      setState(() {
        _justUnarchived = true;
        _enabled = true;
        _archLoading = false;
      });
      return;
    }
  }

  Future<bool> _handleWillPop() async {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    String two(int n) => n.toString().padLeft(2, '0');
    final dateStr = '${two(_date.day)}/${two(_date.month)}/${_date.year}';
    final timeStr = '${two(_time.hour)}:${two(_time.minute)}';
    final autoDateStr = _autoDate == null ? '—' : '${two(_autoDate!.day)}/${two(_autoDate!.month)}/${_autoDate!.year}';
    final autoTimeStr = _autoTime == null ? '—' : '${two(_autoTime!.hour)}:${two(_autoTime!.minute)}';

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Editar Remédio' : 'Novo Remédio'),
          actions: [
            if (isEdit)
              IconButton(
                tooltip: _archived ? 'Desarquivar' : 'Arquivar',
                icon: _archLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_archived ? Icons.unarchive : Icons.archive),
                onPressed: _archLoading ? null : _toggleArchive,
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome do remédio'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data da primeira dose'),
                  subtitle: Text(dateStr),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora da primeira dose'),
                  subtitle: Text(timeStr),
                  trailing: const Icon(Icons.access_time),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hoursCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Intervalo (horas)',
                          hintText: 'Ex.: 8',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Informe as horas';
                          final n = int.tryParse(v);
                          if (n == null || n < 0) return 'Horas inválidas';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Intervalo (minutos)',
                          hintText: '0–59',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Informe os minutos';
                          final n = int.tryParse(v);
                          if (n == null || n < 0 || n > 59) return 'Minutos inválidos';
                          final h = int.tryParse(_hoursCtrl.text) ?? 0;
                          if (h == 0 && n == 0) return 'Intervalo não pode ser 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _enabled || _justUnarchived,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Ativo'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se estiver desarquivando uma medicação, lembrar de ativar os Lembretes.',
                  style: TextStyle(fontSize: 14, color: Colors.redAccent, fontStyle: FontStyle.italic),
                ),
                const Divider(height: 32),
                const Text('Arquivamento automático (opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data'),
                  subtitle: Text(autoDateStr),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_autoDate != null)
                        IconButton(
                          onPressed: () => setState(() => _autoDate = null),
                          icon: const Icon(Icons.clear),
                          tooltip: 'Limpar data',
                        ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                  onTap: _pickAutoDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora'),
                  subtitle: Text(autoTimeStr),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_autoTime != null)
                        IconButton(
                          onPressed: () => setState(() => _autoTime = null),
                          icon: const Icon(Icons.clear),
                          tooltip: 'Limpar hora',
                        ),
                      const Icon(Icons.access_time),
                    ],
                  ),
                  onTap: _pickAutoTime,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                  label: Text(isEdit ? 'Salvar alterações' : 'Adicionar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
