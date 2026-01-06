import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDb {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'meds.db');

    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE medications(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            interval_hours INTEGER NOT NULL,
            interval_minutes INTEGER NOT NULL DEFAULT 0,
            first_dose INTEGER,
            first_dose_at INTEGER,
            last_taken_at INTEGER,
            next_override_at INTEGER,
            enabled INTEGER NOT NULL DEFAULT 1,
            sound TEXT,
            archived INTEGER NOT NULL DEFAULT 0,
            archived_at INTEGER,
            auto_archive_at INTEGER
          );
        ''');

        await db.execute('''
          CREATE TABLE dose_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medication_id INTEGER NOT NULL,
            scheduled_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            recorded_at INTEGER NOT NULL,
            note TEXT,
            UNIQUE(medication_id, scheduled_at)
          );
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _ensureColumn(
            db,
            'medications',
            'interval_minutes',
            'ALTER TABLE medications ADD COLUMN interval_minutes INTEGER NOT NULL DEFAULT 0;',
          );
        }
        if (oldV < 3) {
          await _ensureColumn(
            db,
            'medications',
            'first_dose_at',
            'ALTER TABLE medications ADD COLUMN first_dose_at INTEGER;',
          );
          await _ensureColumn(
            db,
            'medications',
            'next_override_at',
            'ALTER TABLE medications ADD COLUMN next_override_at INTEGER;',
          );
        }
        if (oldV < 4) {
          await _ensureColumn(
            db,
            'medications',
            'archived',
            'ALTER TABLE medications ADD COLUMN archived INTEGER NOT NULL DEFAULT 0;',
          );
          await _ensureColumn(
            db,
            'medications',
            'archived_at',
            'ALTER TABLE medications ADD COLUMN archived_at INTEGER;',
          );
          await _ensureColumn(
            db,
            'medications',
            'auto_archive_at',
            'ALTER TABLE medications ADD COLUMN auto_archive_at INTEGER;',
          );
          await _ensureColumn(
            db,
            'medications',
            'first_dose',
            'ALTER TABLE medications ADD COLUMN first_dose INTEGER;',
          );

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

          final cols = await _cols(db, 'medications');
          if (cols.contains('first_dose_at') && cols.contains('first_dose')) {
            await db.execute(
              'UPDATE medications SET first_dose = first_dose_at WHERE first_dose IS NULL AND first_dose_at IS NOT NULL;',
            );
          }
        }
      },
    );

    return _db!;
  }

  static Future<void> ensureReady() async {
    await instance;
  }

  static Future<Set<String>> _cols(Database db, String table) async {
    final info = await db.rawQuery("PRAGMA table_info('$table')");
    return info.map((e) => (e['name'] ?? '').toString()).toSet();
  }

  static Future<void> _ensureColumn(
      Database db,
      String table,
      String col,
      String sql,
      ) async {
    final cols = await _cols(db, table);
    if (!cols.contains(col)) {
      await db.execute(sql);
    }
  }
}
