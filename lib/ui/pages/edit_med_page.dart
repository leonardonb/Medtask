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
  final _archiveSvc = ArchiveService();
  bool _archived = false;
  bool _archLoading = false;
  bool _justUnarchived = false;
  bool _saved = false;

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

  DateTime _combine(DateTime d, TimeOfDay t) {
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = Get.find<MedListViewModel>();
    final when = _combine(_date, _time);
    final h = int.parse(_hoursCtrl.text);
    final mi = int.parse(_minsCtrl.text);
    final minutes = h * 60 + mi;
    final current = widget.existing;
    final enabledFinal = _justUnarchived ? true : _enabled;

    final med = current == null
        ? Medication(
      id: null,
      name: _nameCtrl.text.trim(),
      firstDose: when,
      intervalMinutes: minutes,
      enabled: enabledFinal,
      sound: 'alert',
    )
        : current.copyWith(
      name: _nameCtrl.text.trim(),
      firstDose: when,
      intervalMinutes: minutes,
      enabled: enabledFinal,
    );

    await vm.upsert(med);
    _saved = true;
    _justUnarchived = false;
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _toggleArchive() async {
    final m = widget.existing;
    if (m?.id == null) return;
    setState(() {
      _archLoading = true;
      if (!_archived) _enabled = false;
    });

    if (_archived) {
      await _archiveSvc.unarchive(m!.id!);
      _justUnarchived = true;
    } else {
      await _archiveSvc.archive(m!.id!);
      await NotificationService.cancelSeries(m.id! * 1000, 12);
      await NotificationHelpers.cancelAllForMed(m.id!, maxPerMed: 64);
      _justUnarchived = false;
    }

    if (Get.isRegistered<MedListViewModel>()) {
      await Get.find<MedListViewModel>().init();
    }

    if (!mounted) return;

    setState(() {
      _archived = !_archived;
      _archLoading = false;
    });

    if (_archived) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicamento desarquivado. Ajuste a data/hora e salve para reativar.')),
    );
  }

  Future<bool> _handleWillPop() async {
    final m = widget.existing;
    if (m?.id != null && _justUnarchived && !_saved) {
      await _archiveSvc.archive(m!.id!);
      await NotificationService.cancelSeries(m.id! * 1000, 12);
      await NotificationHelpers.cancelAllForMed(m.id!, maxPerMed: 64);
      if (Get.isRegistered<MedListViewModel>()) {
        await Get.find<MedListViewModel>().init();
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final two = (int n) => n.toString().padLeft(2, '0');
    final dateStr = '${two(_date.day)}/${two(_date.month)}/${_date.year}';
    final timeStr = '${two(_time.hour)}:${two(_time.minute)}';

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
        body: Form(
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Salvar alterações' : 'Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
