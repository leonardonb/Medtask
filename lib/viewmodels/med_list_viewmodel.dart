import 'dart:math';
import 'dart:async';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import '../core/notification_service.dart';
import '../models/medication.dart';
import '../data/repositories/med_repository.dart';
import '../data/db/app_db.dart';

class MedListViewModel extends GetxController {
  final RxList<Medication> meds = <Medication>[].obs;
  final MedRepository _repo = MedRepository();
  int _lastSweepMs = 0;
  Timer? _sweepTimer;

  @override
  void onInit() {
    super.onInit();
    _sweepTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      tickAutoArchive();
    });
  }

  @override
  void onClose() {
    _sweepTimer?.cancel();
    super.onClose();
  }

  Future<void> init() async {
    final db = await AppDb.instance;
    await _ensureSchema(db);
    await _autoArchiveSweep(db);
    await _reloadActive(db);
  }

  Duration get _grace => const Duration(seconds: 5);

  DateTime nextGrid(Medication m, {DateTime? now}) {
    return m.firstDose;
  }

  DateTime nextFireTime(Medication m, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final target = m.firstDose;
    if (target.isAfter(n.add(_grace))) return target;
    return n.add(_grace);
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
      sound: (m.sound ?? 'alert'),
      repeatEvery: _stepFor(m),
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
        sound: (m.sound ?? 'alert'),
        repeatEvery: _stepFor(m),
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
      sound: (m.sound ?? 'alert'),
      repeatEvery: _stepFor(m),
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
      if (updated.id != null) {
        await NotificationService.cancelAllForMed(updated.id!, medName: updated.name);
      }
    } else {
      await _scheduleFor(updated);
    }
  }

  Future<void> remove(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];
    final base = _baseIdFor(m);
    final rc = _repeatCount();
    meds.removeAt(idx);
    await _repo.delete(id);
    Future(() async {
      await NotificationService.cancelSeries(base, rc);
      if (m.id != null) {
        await NotificationService.cancelAllForMed(m.id!, medName: m.name, maxPerMed: rc);
      }
    });
    final db = await AppDb.instance;
    await _reloadActive(db);
  }

  Future<void> upsert(Medication med) async {
    final db = await AppDb.instance;
    if (med.id == null) {
      final newId = await _repo.insert(med);
      final saved = med.copyWith(id: newId);
      await _autoArchiveSweep(db);
      await _reloadActive(db);
      if (meds.any((e) => e.id == newId)) {
        await _scheduleFor(saved);
      }
      meds.refresh();
    } else {
      await _repo.update(med);
      await _autoArchiveSweep(db);
      await _reloadActive(db);
      final current = meds.firstWhereOrNull((e) => e.id == med.id);
      if (current != null) {
        await _scheduleFor(current);
      }
      meds.refresh();
    }
  }

  Future<void> _ensureSchema(Database db) async {
    final info = await db.rawQuery("PRAGMA table_info('medications')");
    final cols = info.map((e) => (e['name'] ?? '').toString()).toSet();
    if (!cols.contains('archived')) {
      await db.execute('ALTER TABLE medications ADD COLUMN archived INTEGER NOT NULL DEFAULT 0;');
    }
    if (!cols.contains('archived_at')) {
      await db.execute('ALTER TABLE medications ADD COLUMN archived_at INTEGER;');
    }
    if (!cols.contains('auto_archive_at')) {
      await db.execute('ALTER TABLE medications ADD COLUMN auto_archive_at INTEGER;');
    }
    if (!cols.contains('first_dose')) {
      await db.execute('ALTER TABLE medications ADD COLUMN first_dose INTEGER;');
      if (cols.contains('first_dose_at')) {
        await db.execute('UPDATE medications SET first_dose = first_dose_at WHERE first_dose IS NULL;');
      }
    }
  }

  Future<void> _reloadActive(Database db) async {
    final rows = await db.query(
      'medications',
      where: 'archived = 0 AND first_dose IS NOT NULL',
      orderBy: 'name COLLATE NOCASE',
    );
    final active = rows.map((m) => Medication.fromMap(m)).toList();
    meds.assignAll(active);
    await _cancelForInactive(db);
    for (final m in meds) {
      await _scheduleFor(m);
    }
  }

  Future<void> _cancelForInactive(Database db) async {
    final rows = await db.query(
      'medications',
      columns: ['id', 'name'],
      where: 'archived = 1 OR enabled = 0',
    );
    for (final r in rows) {
      final id = r['id'];
      final name = r['name']?.toString();
      if (id is int) {
        await NotificationService.cancelSeries(id * 1000, _repeatCount());
        await NotificationService.cancelAllForMed(id, medName: name);
      }
    }
  }

  Future<void> _autoArchiveSweep(Database db) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'medications',
      columns: ['id', 'name'],
      where: 'archived = 0 AND auto_archive_at IS NOT NULL AND auto_archive_at <= ?',
      whereArgs: [nowMs],
    );
    if (rows.isEmpty) return;

    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      final id = r['id'];
      if (id is int) {
        batch.update(
          'medications',
          {
            'archived': 1,
            'archived_at': now,
            'enabled': 0,
            'auto_archive_at': null,
          },
          where: 'id = ?',
          whereArgs: [id],
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    }
    await batch.commit(noResult: true);

    for (final r in rows) {
      final id = r['id'];
      final name = r['name']?.toString();
      if (id is int) {
        await NotificationService.cancelSeries(id * 1000, _repeatCount());
        await NotificationService.cancelAllForMed(id, medName: name);
      }
    }
  }

  Future<void> tickAutoArchive() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSweepMs < 30000) return;
    final db = await AppDb.instance;
    await _autoArchiveSweep(db);
    await _reloadActive(db);
    _lastSweepMs = now;
  }
}
