import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDb {
  static Database? _db;
  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'meds.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE medications(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            interval_hours INTEGER NOT NULL,
            interval_minutes INTEGER NOT NULL DEFAULT 0,
            first_dose_at INTEGER,
            last_taken_at INTEGER,
            next_override_at INTEGER,
            enabled INTEGER NOT NULL DEFAULT 1,
            sound TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE dose_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medication_id INTEGER NOT NULL,
            taken_at INTEGER NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute(
              'ALTER TABLE medications ADD COLUMN interval_minutes INTEGER NOT NULL DEFAULT 0;');
        }
        if (oldV < 3) {
          await db.execute(
              'ALTER TABLE medications ADD COLUMN first_dose_at INTEGER;');
          await db.execute(
              'ALTER TABLE medications ADD COLUMN next_override_at INTEGER;');
        }
      },
    );
    return _db!;
  }
}
