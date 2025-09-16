import 'package:sqflite/sqflite.dart';
import '../../data/db/app_db.dart';
import '../../core/notification_service.dart';

class ArchivedMed {
  final int id;
  final String name;
  final DateTime? archivedAt;

  ArchivedMed({required this.id, required this.name, this.archivedAt});
}

class ArchiveService {
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
  }

  Future<bool> isArchived(int id) async {
    final db = await AppDb.instance;
    await _ensureSchema(db);
    final rows = await db.query('medications', columns: ['archived'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return false;
    final v = rows.first['archived'];
    if (v is int) return v == 1;
    if (v is bool) return v;
    return false;
  }

  Future<void> archive(int id) async {
    final db = await AppDb.instance;
    await _ensureSchema(db);
    final future10y = DateTime.now().add(const Duration(days: 3650)).millisecondsSinceEpoch;
    await db.update(
      'medications',
      {
        'archived': 1,
        'archived_at': DateTime.now().millisecondsSinceEpoch,
        'enabled': 0,
        'first_dose_at': future10y,
        'next_override_at': null,
        'auto_archive_at': null
      },
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    await NotificationService.cancelAllForMed(id, maxPerMed: 64);
  }

  Future<void> unarchive(int id) async {
    final db = await AppDb.instance;
    await _ensureSchema(db);
    final soon = DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch;
    await db.update(
      'medications',
      {
        'archived': 0,
        'archived_at': null,
        'enabled': 0,
        'first_dose_at': soon,
        'next_override_at': null
      },
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<ArchivedMed>> listArchived() async {
    final db = await AppDb.instance;
    await _ensureSchema(db);
    final rows = await db.query(
      'medications',
      columns: ['id', 'name', 'archived_at'],
      where: 'archived = ?',
      whereArgs: [1],
      orderBy: 'archived_at DESC',
    );
    return rows.map((m) {
      final ts = m['archived_at'];
      final dt = ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
      return ArchivedMed(
        id: m['id'] as int,
        name: (m['name'] ?? '').toString(),
        archivedAt: dt,
      );
    }).toList();
  }
}
