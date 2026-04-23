import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<void> reset() async {
    await _db?.close();
    _db = null;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'fitnesstracker.db');
    return openDatabase(
      path,
      version: DbMigrations.currentVersion,
      onCreate: DbMigrations.onCreate,
      onUpgrade: DbMigrations.onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }
}
