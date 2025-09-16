import 'package:sqflite/sqflite.dart';
import '../../models/medication.dart';
import '../db/app_db.dart';

class MedRepository {
  Future<Database> get _db async => await AppDb.instance;

  Future<void> _ensureSchema(Database db) async {
    final info = await db.rawQuery("PRAGMA table_info('medications')");
    final cols = info.map((e) => (e['name'] ?? '').toString()).toSet();
    if (!cols.contains('archived')) {
      await db.execute('ALTER TABLE medications ADD COLUMN archived INTEGER NOT NULL DEFAULT 0;');
    }
    if (!cols.contains('archived_at')) {
      await db.execute('ALTER TABLE medications ADD COLUMN archived_at INTEGER;');
    }
  }

  Future<List<Medication>> getAll() async {
    final db = await _db;
    await _ensureSchema(db);
    final rows = await db.query('medications', orderBy: 'name COLLATE NOCASE');
    return rows.map(Medication.fromMap).toList();
  }

  Future<List<Medication>> getAllActive() async {
    final db = await _db;
    await _ensureSchema(db);
    final rows = await db.query(
      'medications',
      where: 'archived = 0 AND enabled = 1 AND first_dose_at IS NOT NULL',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Medication.fromMap).toList();
  }

  Future<List<Medication>> getAllArchived() async {
    final db = await _db;
    await _ensureSchema(db);
    final rows = await db.query(
      'medications',
      where: 'archived = 1',
      orderBy: 'archived_at DESC',
    );
    return rows.map(Medication.fromMap).toList();
  }

  Future<Medication?> getById(int id) async {
    final db = await _db;
    await _ensureSchema(db);
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final map = Map<String, Object?>.from(rows.first);
    if (map['first_dose_at'] == null) {
      map['first_dose_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    return Medication.fromMap(map);
  }

  Future<int> insert(Medication m) async {
    final db = await _db;
    await _ensureSchema(db);
    final total = m.intervalMinutes;
    final h = total ~/ 60;
    final mi = total % 60;
    final data = <String, Object?>{
      'name': m.name,
      'interval_hours': h,
      'interval_minutes': mi,
      'first_dose_at': m.firstDose.millisecondsSinceEpoch,
      'last_taken_at': null,
      'next_override_at': null,
      'enabled': m.enabled ? 1 : 0,
      'sound': m.sound,
      'archived': 0,
      'archived_at': null,
    };
    return await db.insert('medications', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> update(Medication m) async {
    final db = await _db;
    await _ensureSchema(db);
    final total = m.intervalMinutes;
    final h = total ~/ 60;
    final mi = total % 60;
    final data = <String, Object?>{
      'name': m.name,
      'interval_hours': h,
      'interval_minutes': mi,
      'first_dose_at': m.firstDose.millisecondsSinceEpoch,
      'enabled': m.enabled ? 1 : 0,
      'sound': m.sound,
    };
    await db.update(
      'medications',
      data,
      where: 'id = ?',
      whereArgs: [m.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await _ensureSchema(db);
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }
}
