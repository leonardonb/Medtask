import 'dart:math';
import 'dart:async';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import '../core/notification_service.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../data/repositories/med_repository.dart';
import '../data/repositories/dose_repository.dart';
import '../data/db/app_db.dart';

class MedListViewModel extends GetxController {
  final RxList<Medication> meds = <Medication>[].obs;
  final MedRepository _repo = MedRepository();
  final DoseRepository _doseRepo = DoseRepository();

  int _lastSweepMs = 0;
  Timer? _sweepTimer;
  Timer? _autoMissedTimer;

  static const Duration missedAfter = Duration(hours: 6);

  @override
  void onClose() {
    _sweepTimer?.cancel();
    _autoMissedTimer?.cancel();
    super.onClose();
  }

  Future<void> init() async {
    final db = await AppDb.instance;
    await _reloadActive(db);
    await _ensureSchema(db);
    await _autoArchiveSweep(db);
    await _reloadActive(db);
    await _autoMissedSweep(db);
    _startTimers();
  }

  Future<void> reload() async {
    final db = await AppDb.instance;
    await _ensureSchema(db);
    await _autoArchiveSweep(db);
    await _autoMissedSweep(db);
    await _reloadActive(db);
  }

  void _startTimers() {
    _sweepTimer?.cancel();
    _sweepTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final db = await AppDb.instance;
      await _autoArchiveSweep(db);
      await _reloadActive(db);
    });

    _autoMissedTimer?.cancel();
    _autoMissedTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final db = await AppDb.instance;
      await _autoMissedSweep(db);
    });
  }

  Duration get _grace => const Duration(seconds: 5);

  int _baseIdFor(Medication m) => (m.id ?? 0) * 1000;

  int _repeatCount() => 12;

  Duration _stepFor(Medication m) => Duration(minutes: max(1, m.intervalMinutes));

  DateTime nextFireTime(Medication m, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final target = m.firstDose;
    if (target.isAfter(n.add(_grace))) return target;
    return n.add(_grace);
  }

  Future<void> _scheduleFor(Medication m) async {
    if (m.id == null) return;
    final baseId = _baseIdFor(m);
    if (!m.enabled) {
      await NotificationService.cancelSeries(baseId, _repeatCount());
      return;
    }
    await NotificationService.scheduleSeries(
      baseId: baseId,
      firstWhen: nextFireTime(m),
      title: 'Hora do remédio',
      body: m.name,
      sound: (m.sound ?? 'alert'),
      repeatEvery: _stepFor(m),
      repeatCount: _repeatCount(),
      payload: 'med:${m.id}',
    );
  }

  Future<void> rescheduleAllAfterSoundChange() async {
    final db = await AppDb.instance;
    await _ensureSchema(db);
    final rows = await db.query('medications');
    await NotificationService.rescheduleAllAfterSoundChange(
      meds: rows,
      intervalFn: (m) {
        final h = (m['interval_hours'] as int?) ?? 0;
        final mi = (m['interval_minutes'] as int?) ?? 0;
        final total = max(1, (h * 60) + mi);
        return Duration(minutes: total);
      },
      nextFn: (m) {
        final fd = (m['first_dose'] as int?) ??
            (m['first_dose_at'] as int?) ??
            DateTime.now().millisecondsSinceEpoch;
        return DateTime.fromMillisecondsSinceEpoch(fd);
      },
    );
    await _reloadActive(db);
  }

  Future<void> markTaken(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];

    final now = DateTime.now();
    final scheduledAt = m.firstDose;

    await _doseRepo.upsertDoseEvent(
      DoseEvent(
        medicationId: id,
        scheduledAt: scheduledAt,
        status: DoseStatus.taken,
        recordedAt: now,
      ),
    );

    final updated = m.copyWith(firstDose: m.firstDose.add(_stepFor(m)));
    meds[idx] = updated;
    await _repo.update(updated);
    await _scheduleFor(updated);
  }

  Future<void> skipNext(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];

    final now = DateTime.now();
    final scheduledAt = m.firstDose;

    await _doseRepo.upsertDoseEvent(
      DoseEvent(
        medicationId: id,
        scheduledAt: scheduledAt,
        status: DoseStatus.skipped,
        recordedAt: now,
      ),
    );

    final updated = m.copyWith(firstDose: m.firstDose.add(_stepFor(m)));
    meds[idx] = updated;
    await _repo.update(updated);
    await _scheduleFor(updated);
  }

  Future<void> markMissed(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];

    final now = DateTime.now();
    final scheduledAt = m.firstDose;

    await _doseRepo.upsertDoseEvent(
      DoseEvent(
        medicationId: id,
        scheduledAt: scheduledAt,
        status: DoseStatus.missed,
        recordedAt: now,
      ),
    );

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

  Future<void> toggleEnabled(int id, bool enabled) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = meds[idx];
    final updated = m.copyWith(enabled: enabled);
    meds[idx] = updated;
    await _repo.update(updated);
    if (!enabled) {
      await NotificationService.cancelSeries(_baseIdFor(updated), _repeatCount());
      return;
    }
    await _scheduleFor(updated);
  }

  Future<void> remove(int id) async {
    final idx = meds.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      final m = meds[idx];
      if (m.id != null) {
        await NotificationService.cancelAllForMed(m.id!);
      }
      meds.removeAt(idx);
    }
    await _repo.delete(id);
  }

  Future<void> upsert(Medication m) async {
    if (m.id == null) {
      final id = await _repo.insert(m);
      final inserted = m.copyWith(id: id);
      meds.add(inserted);
      await _scheduleFor(inserted);
      return;
    }
    final idx = meds.indexWhere((e) => e.id == m.id);
    if (idx >= 0) {
      meds[idx] = m;
    } else {
      meds.add(m);
    }
    await _repo.update(m);
    await _scheduleFor(m);
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
    }

    final cols2 = await db.rawQuery("PRAGMA table_info('medications')");
    final hasFirstDose = cols2.any((e) => (e['name'] ?? '').toString() == 'first_dose');
    final hasFirstDoseAt = cols2.any((e) => (e['name'] ?? '').toString() == 'first_dose_at');

    if (hasFirstDose && hasFirstDoseAt) {
      await db.execute(
        'UPDATE medications SET first_dose = first_dose_at WHERE first_dose IS NULL AND first_dose_at IS NOT NULL;',
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dose_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        scheduled_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        recorded_at INTEGER NOT NULL,
        note TEXT,
        UNIQUE(medication_id, scheduled_at)
      );
    ''');
  }

  Future<void> _reloadActive(Database db) async {
    await _ensureSchema(db);
    final list = await _repo.getAllActive();
    meds.assignAll(list);
    await _cancelForInactive(db, list);
    for (final m in list) {
      await _scheduleFor(m);
    }
    meds.refresh();
  }

  Future<void> _cancelForInactive(Database db, List<Medication> active) async {
    final activeIds = active.map((e) => e.id).whereType<int>().toSet();
    final rows = await db.query(
      'medications',
      columns: ['id', 'enabled', 'archived'],
    );

    for (final r in rows) {
      final id = r['id'] as int?;
      if (id == null) continue;
      final enabled = (r['enabled'] as int?) == 1;
      final archived = (r['archived'] as int?) == 1;

      if (archived || !enabled || !activeIds.contains(id)) {
        await NotificationService.cancelAllForMed(id);
      }
    }
  }

  Future<void> _autoArchiveSweep(Database db) async {
    await _ensureSchema(db);
    final now = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'medications',
      columns: ['id', 'auto_archive_at', 'archived', 'enabled'],
      where: 'archived = 0 AND enabled = 1 AND auto_archive_at IS NOT NULL',
    );

    for (final r in rows) {
      final id = r['id'] as int?;
      final aa = r['auto_archive_at'] as int?;
      if (id == null || aa == null) continue;
      if (aa <= now) {
        await db.update(
          'medications',
          {'archived': 1, 'archived_at': now, 'enabled': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
        await NotificationService.cancelAllForMed(id);
      }
    }
  }

  Future<void> _autoMissedSweep(Database db) async {
    await _ensureSchema(db);

    final now = DateTime.now();
    final threshold = now.subtract(missedAfter);

    final list = await _repo.getAllActive();
    if (list.isEmpty) return;

    bool anyChanged = false;

    for (final m in list) {
      if (m.id == null) continue;
      if (!m.enabled) continue;

      final id = m.id!;
      final step = _stepFor(m);

      DateTime current = m.firstDose;
      int safety = 0;

      while (!current.isAfter(threshold)) {
        final exists = await _doseRepo.existsEvent(id, current);
        if (!exists) {
          await _doseRepo.upsertDoseEvent(
            DoseEvent(
              medicationId: id,
              scheduledAt: current,
              status: DoseStatus.missed,
              recordedAt: now,
            ),
          );
        }
        current = current.add(step);
        safety++;
        if (safety > 500) break;
      }

      if (current.millisecondsSinceEpoch != m.firstDose.millisecondsSinceEpoch) {
        await _repo.update(m.copyWith(firstDose: current));
        anyChanged = true;
      }
    }

    if (anyChanged) {
      final db2 = await AppDb.instance;
      await _reloadActive(db2);
    }
  }

  Future<void> tickAutoArchive() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSweepMs < 30000) return;
    final db = await AppDb.instance;
    await _autoArchiveSweep(db);
    await _autoMissedSweep(db);
    await _reloadActive(db);
    _lastSweepMs = now;
  }
}
