import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../models/medication.dart';

class MedRepository {
  static final MedRepository _i = MedRepository._internal();
  factory MedRepository() => _i;
  MedRepository._internal();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    final dbPath = p.join(base, 'medtask.db');
    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE meds(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            first_dose INTEGER NOT NULL,
            interval_minutes INTEGER NOT NULL,
            enabled INTEGER NOT NULL,
            sound TEXT
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // v1 -> v2: adicionar sound/interval_minutes e migrar interval_hours
        if (oldV <= 1) {
          await db.execute('ALTER TABLE meds ADD COLUMN sound TEXT');
          final cols = await db.rawQuery(
              "PRAGMA table_info(meds)"); // verifica se já existe interval_minutes
          final hasIntervalMinutes = cols.any(
                  (c) => (c['name'] as String?)?.toLowerCase() == 'interval_minutes');
          if (!hasIntervalMinutes) {
            await db.execute('ALTER TABLE meds ADD COLUMN interval_minutes INTEGER');
          }
          final rows = await db.query('meds');
          for (final r in rows) {
            final id = r['id'] as int;
            final ih = r['interval_hours'] as int?;
            final im = r['interval_minutes'] as int?;
            final firstDose = r['first_dose'] as int?;
            final newIM = im ?? ((ih ?? 8) * 60);
            final newFD = firstDose ?? DateTime.now().millisecondsSinceEpoch;
            await db.update('meds', {
              'interval_minutes': newIM,
              'first_dose': newFD,
            }, where: 'id = ?', whereArgs: [id]);
          }
          // recria tabela sem interval_hours se existir
          final hasIntervalHours = cols.any(
                  (c) => (c['name'] as String?)?.toLowerCase() == 'interval_hours');
          if (hasIntervalHours) {
            await db.execute(
                'CREATE TEMP TABLE meds_old AS SELECT id,name,first_dose,interval_minutes,enabled,sound FROM meds');
            await db.execute('DROP TABLE meds');
            await db.execute('''
              CREATE TABLE meds(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                first_dose INTEGER NOT NULL,
                interval_minutes INTEGER NOT NULL,
                enabled INTEGER NOT NULL,
                sound TEXT
              )
            ''');
            await db.execute('INSERT INTO meds SELECT * FROM meds_old');
            await db.execute('DROP TABLE meds_old');
          }
        }
        // v2 -> v3: reforça defaults se algo ficou nulo
        if (oldV <= 2) {
          final rows = await db.query('meds');
          for (final r in rows) {
            final id = r['id'] as int;
            final fd = r['first_dose'] as int?;
            final im = r['interval_minutes'] as int?;
            await db.update(
              'meds',
              {
                if (fd == null)
                  'first_dose': DateTime.now().millisecondsSinceEpoch,
                if (im == null) 'interval_minutes': 480,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      },
    );
    return _db!;
  }

  Future<List<Medication>> getAll() async {
    final db = await _open();
    final rows = await db.query('meds', orderBy: 'name COLLATE NOCASE');
    return rows.map((e) => Medication.fromMap(e)).toList();
  }

  Future<int> insert(Medication m) async {
    final db = await _open();
    return await db.insert('meds', m.toMap()..remove('id'));
  }

  Future<void> update(Medication m) async {
    final db = await _open();
    await db.update('meds', m.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('meds', where: 'id = ?', whereArgs: [id]);
  }
}
