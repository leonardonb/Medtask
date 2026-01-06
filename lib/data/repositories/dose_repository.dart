import 'package:sqflite/sqflite.dart';
import '../db/app_db.dart';
import '../../models/dose_log.dart';

class DoseRepository {
  Future<Database> get _db async => await AppDb.instance;

  Future<void> ensureSchema() async {
    final db = await _db;
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

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dose_events_scheduled_at
      ON dose_events(scheduled_at);
    ''');
  }

  Future<void> upsertDoseEvent(DoseEvent e) async {
    final db = await _db;
    await ensureSchema();

    await db.insert(
      'dose_events',
      {
        'medication_id': e.medicationId,
        'scheduled_at': e.scheduledAt.millisecondsSinceEpoch,
        'status': DoseEvent.statusToDb(e.status),
        'recorded_at': e.recordedAt.millisecondsSinceEpoch,
        'note': e.note,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> existsEvent(int medicationId, DateTime scheduledAt) async {
    final db = await _db;
    await ensureSchema();

    final rows = await db.query(
      'dose_events',
      columns: ['id'],
      where: 'medication_id = ? AND scheduled_at = ?',
      whereArgs: [medicationId, scheduledAt.millisecondsSinceEpoch],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<DoseEventItem>> listRecentWithMedication({int limit = 100}) async {
    final db = await _db;
    await ensureSchema();

    final rows = await db.rawQuery('''
      SELECT 
        de.id AS id,
        de.medication_id AS medication_id,
        de.scheduled_at AS scheduled_at,
        de.status AS status,
        de.recorded_at AS recorded_at,
        de.note AS note,
        m.name AS medication_name
      FROM dose_events de
      LEFT JOIN medications m ON m.id = de.medication_id
      ORDER BY de.scheduled_at DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((r) {
      final ev = DoseEvent.fromMap(r);
      final name = (r['medication_name'] as String?) ?? 'Remédio';
      return DoseEventItem(event: ev, medicationName: name);
    }).toList();
  }

  Future<DoseStatus?> getEventStatus(int medicationId, DateTime scheduledAt) async {
    final db = await AppDb.instance;

    final rows = await db.query(
      'dose_events',
      columns: ['status'],
      where: 'medication_id = ? AND scheduled_at = ?',
      whereArgs: [medicationId, scheduledAt.millisecondsSinceEpoch],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return DoseEvent.statusFromDb(rows.first['status']);
  }
}
