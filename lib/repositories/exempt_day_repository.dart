import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

Future<List<ExemptDay>> getExemptDaysForRange(
  Database db,
  String startDate,
  String endDate,
) async {
  final rows = await db.rawQuery(
    'SELECT * FROM exempt_days WHERE date BETWEEN ? AND ? ORDER BY date ASC',
    [startDate, endDate],
  );
  return rows.map(ExemptDay.fromMap).toList();
}

Future<ExemptDay?> getExemptDay(Database db, String date) async {
  final rows = await db.rawQuery('SELECT * FROM exempt_days WHERE date = ?', [date]);
  return rows.isEmpty ? null : ExemptDay.fromMap(rows.first);
}

Future<void> setExemptDay(Database db, String date, String? reason) async {
  await db.rawInsert(
    'INSERT OR REPLACE INTO exempt_days (date, reason) VALUES (?, ?)',
    [date, reason],
  );
}

Future<void> removeExemptDay(Database db, String date) async {
  await db.rawDelete('DELETE FROM exempt_days WHERE date = ?', [date]);
}
