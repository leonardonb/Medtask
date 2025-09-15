import 'dart:math';
import 'package:get/get.dart';
import '../core/notification_service.dart';
import '../models/medication.dart';
import '../data/repositories/med_repository.dart';

class MedListViewModel extends GetxController {
  final RxList<Medication> meds = <Medication>[].obs;
  final MedRepository _repo = MedRepository();

  Future<void> init() async {
    final all = await _repo.getAll();
    meds.assignAll(all);
    for (final m in meds) {
      await _scheduleFor(m);
    }
  }

  Duration get _grace => const Duration(seconds: 5);

  DateTime nextGrid(Medication m, {DateTime? now}) {
    return m.firstDose;
  }

  DateTime nextFireTime(Medication m, {DateTime? now}) {
    final _now = now ?? DateTime.now();
    final target = m.firstDose;
    if (target.isAfter(_now.add(_grace))) return target;
    return _now.add(_grace);
  }

  int _baseIdFor(Medication m) => (m.id ?? 0) * 1000;
  int _repeatCount() => 12;

  Future<void> _scheduleFor(Medication m) async {
    if (m.id == null || !m.enabled) return;
    await NotificationService.cancelSeries(_baseIdFor(m), _repeatCount());
    final fireAt = nextFireTime(m);
    await NotificationService.scheduleSeries(
      baseId: _baseIdFor(m),
      firstWhen: fireAt,
      title: 'Hora do remédio',
      body: m.name,
      sound: m.sound,
      repeatEvery: const Duration(minutes: 5),
      repeatCount: _repeatCount(),
      payload: 'med:${m.id}',
    );
    meds.refresh();
  }

  Future<void> rescheduleAllAfterSoundChange() async {
    for (final m in meds) {
      if (m.id == null || !m.enabled) continue;
      await NotificationService.cancelSeries(_baseIdFor(m), _repeatCount());
      final fireAt = nextFireTime(m);
      await NotificationService.scheduleSeries(
        baseId: _baseIdFor(m),
        firstWhen: fireAt,
        title: 'Hora do remédio',
        body: m.name,
        sound: m.sound,
        repeatEvery: const Duration(minutes: 5),
        repeatCount: _repeatCount(),
        payload: 'med:${m.id}',
      );
    }
    meds.refresh();
  }

  Duration _stepFor(Medication m) => Duration(minutes: max(1, m.intervalMinutes));

  Future<void> markTaken(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];
    final updated = m.copyWith(firstDose: m.firstDose.add(_stepFor(m)));
    meds[idx] = updated;
    await _repo.update(updated);
    await _scheduleFor(updated);
  }

  Future<void> skipNext(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];
    final updated = m.copyWith(firstDose: m.firstDose.add(_stepFor(m)));
    meds[idx] = updated;
    await _repo.update(updated);
    await _scheduleFor(updated);
  }

  Future<void> rewindPrevious(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];
    final updated = m.copyWith(firstDose: m.firstDose.subtract(_stepFor(m)));
    meds[idx] = updated;
    await _repo.update(updated);
    await _scheduleFor(updated);
  }

  Future<DateTime?> postponeAlarm(int id, Duration d) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final m = meds[idx];
    await NotificationService.cancelSeries(_baseIdFor(m), _repeatCount());
    final first = DateTime.now().add(d);
    await NotificationService.scheduleSeries(
      baseId: _baseIdFor(m),
      firstWhen: first,
      title: 'Hora do remédio',
      body: m.name,
      sound: m.sound,
      repeatEvery: const Duration(minutes: 5),
      repeatCount: _repeatCount(),
      payload: 'med:${m.id}',
    );
    meds.refresh();
    return first;
  }

  Future<void> toggleEnabled(int id, bool enabled) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];
    final updated = m.copyWith(enabled: enabled);
    meds[idx] = updated;
    await _repo.update(updated);
    if (!enabled) {
      await NotificationService.cancelSeries(_baseIdFor(updated), _repeatCount());
    } else {
      await _scheduleFor(updated);
    }
  }

  Future<void> remove(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];
    meds.removeAt(idx);
    await NotificationService.cancelSeries(_baseIdFor(m), _repeatCount());
    await _repo.delete(id);
  }

  Future<void> upsert(Medication med) async {
    if (med.id == null) {
      final newId = await _repo.insert(med);
      final saved = med.copyWith(id: newId);
      meds.add(saved);
      await _scheduleFor(saved);
    } else {
      await _repo.update(med);
      final idx = meds.indexWhere((e) => e.id == med.id);
      if (idx >= 0) meds[idx] = med;
      await _scheduleFor(med);
    }
  }
}
