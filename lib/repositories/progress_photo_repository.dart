import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

Future<List<ProgressPhoto>> getPhotosForDate(Database db, String date) async {
  final rows = await db.rawQuery(
    'SELECT * FROM progress_photos WHERE date = ? ORDER BY created_at ASC',
    [date],
  );
  return rows.map(ProgressPhoto.fromMap).toList();
}

Future<List<ProgressPhoto>> getRecentPhotos(Database db, {int limit = 300}) async {
  final rows = await db.rawQuery(
    'SELECT * FROM progress_photos ORDER BY date DESC, created_at DESC LIMIT ?',
    [limit],
  );
  return rows.map(ProgressPhoto.fromMap).toList();
}

Future<int> insertPhoto(Database db, String date, String fileUri) =>
    db.rawInsert(
      'INSERT INTO progress_photos (date, file_uri) VALUES (?, ?)',
      [date, fileUri],
    );

Future<void> deletePhoto(Database db, int id) async {
  await db.rawDelete('DELETE FROM progress_photos WHERE id = ?', [id]);
}

Future<void> updatePhotoDate(Database db, int id, String date) async {
  await db.rawUpdate('UPDATE progress_photos SET date = ? WHERE id = ?', [date, id]);
}
