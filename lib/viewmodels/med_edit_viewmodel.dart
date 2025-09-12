import 'package:get/get.dart';

import '../models/medication.dart';
import '../viewmodels/med_list_viewmodel.dart';

class MedEditViewModel extends GetxController {
  final name = ''.obs;
  final intervalHours = 8.obs;        // default 8h
  final intervalMinutes = 0.obs;      // +0 min
  final firstDoseAt = Rxn<DateTime>(); // usuário escolhe; default no save()
  final sound = 'alert'.obs;
  final enabled = true.obs;

  void loadFrom(Medication m) {
    name.value = m.name;
    intervalHours.value = m.intervalMinutes ~/ 60;
    intervalMinutes.value = m.intervalMinutes % 60;
    firstDoseAt.value = m.firstDose;
    sound.value = m.sound ?? 'alert';
    enabled.value = m.enabled;
  }

  Future<void> save({Medication? base}) async {
    final totalMinutes = (intervalHours.value * 60) + intervalMinutes.value;
    final safeInterval = totalMinutes <= 0 ? 1 : totalMinutes;

    final when = firstDoseAt.value ?? DateTime.now().add(const Duration(seconds: 5));

    final med = Medication(
      id: base?.id,
      name: name.value.trim().isEmpty ? 'Remédio' : name.value.trim(),
      firstDose: when,
      intervalMinutes: safeInterval,
      enabled: enabled.value,
      sound: sound.value.trim().isEmpty ? null : sound.value.trim(),
    );

    final listVm = Get.find<MedListViewModel>();
    await listVm.upsert(med);
  }
}
