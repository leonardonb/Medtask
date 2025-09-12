import 'package:get/get.dart';
import '../models/medication.dart';
import 'med_list_viewmodel.dart';

class MedEditViewModel extends GetxController {
  final name = ''.obs;
  final intervalHours = 8.obs;
  final intervalMinutes = 0.obs;
  final firstDoseAt = Rxn<DateTime>();
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
    final totalMinutes = intervalHours.value * 60 + intervalMinutes.value;
    final med = Medication(
      id: base?.id,
      name: name.value.trim(),
      firstDose: firstDoseAt.value ?? DateTime.now(),
      intervalMinutes: totalMinutes,
      enabled: enabled.value,
      sound: sound.value.trim().isEmpty ? null : sound.value.trim(),
    );
    await Get.find<MedListViewModel>().upsert(med);
  }
}
