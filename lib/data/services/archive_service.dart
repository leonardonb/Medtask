import 'package:sqflite/sqflite.dart';

import '../db/app_db.dart';
import '../../core/notification_service.dart';

class ArchivedMed {
  final int id;
  final String name;
  final DateTime? archivedAt;

  ArchivedMed({required this.id, required this.name, this.archivedAt});
}

class ArchiveService {
  Future<Database> get _db async => await AppDb.instance;

  Future<bool> isArchived(int id) async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      columns: ['archived'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['archived'] as int?) == 1;
  }

  Future<void> archive(int id) async {
    final db = await _db;
    await db.update(
      'medications',
      {
        'archived': 1,
        'archived_at': DateTime.now().millisecondsSinceEpoch,
        'enabled': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await NotificationService.cancelAllForMed(id, maxPerMed: 64);
  }

  Future<void> unarchive(int id) async {
    final db = await _db;
    await db.update(
      'medications',
      {
        'archived': 0,
        'archived_at': null,
        'enabled': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ArchivedMed>> listArchived() async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      columns: ['id', 'name', 'archived_at'],
      where: 'archived = 1',
      orderBy: 'archived_at DESC',
    );

    return rows
        .map(
          (e) => ArchivedMed(
        id: e['id'] as int,
        name: (e['name'] as String?) ?? 'Remédio',
        archivedAt: (e['archived_at'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(e['archived_at'] as int),
      ),
    )
        .toList();
  }
}
