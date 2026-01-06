import 'package:sqflite/sqflite.dart';
import '../../models/medication.dart';
import '../db/app_db.dart';

class MedRepository {
  Future<Database> get _db async => await AppDb.instance;

  Map<String, Object?> _rowCompat(Map<String, Object?> row) {
    final map = Map<String, Object?>.from(row);
    if (map['first_dose'] == null && map['first_dose_at'] != null) {
      map['first_dose'] = map['first_dose_at'];
    }
    return map;
  }

  Future<List<Medication>> getAll() async {
    final db = await _db;
    final rows = await db.query('medications', orderBy: 'name COLLATE NOCASE');
    return rows.map((m) => Medication.fromMap(_rowCompat(m))).toList();
  }

  Future<List<Medication>> getAllActive() async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      where: 'archived = 0 AND enabled = 1 AND first_dose IS NOT NULL',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((m) => Medication.fromMap(_rowCompat(m))).toList();
  }

  Future<List<Medication>> getAllArchived() async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      where: 'archived = 1',
      orderBy: 'archived_at DESC',
    );
    return rows.map((m) => Medication.fromMap(_rowCompat(m))).toList();
  }

  Future<Medication?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final map = _rowCompat(rows.first);
    if (map['first_dose'] == null) {
      map['first_dose'] = DateTime.now().millisecondsSinceEpoch;
    }
    return Medication.fromMap(map);
  }

  Future<int> insert(Medication m) async {
    final db = await _db;
    final total = m.intervalMinutes;
    final h = total ~/ 60;
    final mi = total % 60;
    final data = <String, Object?>{
      'name': m.name,
      'interval_hours': h,
      'interval_minutes': mi,
      'first_dose': m.firstDose.millisecondsSinceEpoch,
      'first_dose_at': m.firstDose.millisecondsSinceEpoch,
      'last_taken_at': null,
      'next_override_at': null,
      'enabled': m.enabled ? 1 : 0,
      'sound': m.sound,
      'archived': 0,
      'archived_at': null,
      'auto_archive_at': m.autoArchiveAt?.millisecondsSinceEpoch,
    };
    return await db.insert('medications', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> update(Medication m) async {
    final db = await _db;
    final total = m.intervalMinutes;
    final h = total ~/ 60;
    final mi = total % 60;
    final data = <String, Object?>{
      'name': m.name,
      'interval_hours': h,
      'interval_minutes': mi,
      'first_dose': m.firstDose.millisecondsSinceEpoch,
      'first_dose_at': m.firstDose.millisecondsSinceEpoch,
      'enabled': m.enabled ? 1 : 0,
      'sound': m.sound,
      'auto_archive_at': m.autoArchiveAt?.millisecondsSinceEpoch,
    };
    await db.update(
      'medications',
      data,
      where: 'id = ?',
      whereArgs: [m.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateNextDose(int id, DateTime nextDose) async {
    final db = await _db;
    await db.update(
      'medications',
      {
        'first_dose': nextDose.millisecondsSinceEpoch,
        'first_dose_at': nextDose.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }
}
