import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../viewmodels/med_edit_viewmodel.dart';
import '../../models/medication.dart';
import '../../utils/dt.dart';

class EditMedPage extends StatefulWidget {
  final Medication? existing;
  const EditMedPage({super.key, this.existing});

  @override
  State<EditMedPage> createState() => _EditMedPageState();
}

class _EditMedPageState extends State<EditMedPage> {
  final _form = GlobalKey<FormState>();
  late final MedEditViewModel vm;

  final _name = TextEditingController();
  final _h = TextEditingController(text: '8');
  final _m = TextEditingController(text: '0');
  final _sound = TextEditingController(text: 'alert');
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    vm = Get.put(MedEditViewModel());
    final e = widget.existing;
    if (e != null) {
      vm.loadFrom(e);
      _name.text = e.name;
      _h.text = (e.intervalMinutes ~/ 60).toString();
      _m.text = (e.intervalMinutes % 60).toString();
      _sound.text = e.sound ?? 'alert';
      _enabled = e.enabled;
    }
  }

  @override
  void dispose() {
    Get.delete<MedEditViewModel>();
    super.dispose();
  }

  Future<void> _pickFirstDose() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: vm.firstDoseAt.value ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(vm.firstDoseAt.value ?? now),
    );
    if (t == null) return;
    vm.firstDoseAt.value = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final firstLabel = vm.firstDoseAt.value == null
        ? 'Definir'
        : dtFmt(vm.firstDoseAt.value!);

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Novo' : 'Editar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome do remédio'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                onChanged: (v) => vm.name.value = v,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _h,
                      decoration: const InputDecoration(labelText: 'Horas'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0) return '>= 0';
                        return null;
                      },
                      onChanged: (v) => vm.intervalHours.value = int.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _m,
                      decoration: const InputDecoration(labelText: 'Minutos'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 59) return '0..59';
                        return null;
                      },
                      onChanged: (v) => vm.intervalMinutes.value = int.tryParse(v) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Primeira dose'),
                subtitle: Text(firstLabel),
                trailing: OutlinedButton(
                  onPressed: _pickFirstDose,
                  child: const Text('Escolher'),
                ),
              ),
              TextFormField(
                controller: _sound,
                decoration: const InputDecoration(labelText: 'Som (raw, ex.: alert)'),
                onChanged: (v) => vm.sound.value = v,
              ),
              SwitchListTile(
                title: const Text('Ativo'),
                value: _enabled,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  vm.enabled.value = v;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  FocusScope.of(context).unfocus();
                  await vm.save(base: widget.existing);
                  if (mounted) Get.back(result: true);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
