import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

Future<List<Exercise>> getAllExercises(Database db) async {
  final rows = await db.rawQuery('SELECT * FROM exercises ORDER BY name ASC');
  return rows.map(Exercise.fromMap).toList();
}

Future<Exercise?> getExerciseById(Database db, int id) async {
  final rows = await db.rawQuery('SELECT * FROM exercises WHERE id = ?', [id]);
  return rows.isEmpty ? null : Exercise.fromMap(rows.first);
}

Future<int> createExercise(Database db, String name, String description) =>
    db.rawInsert(
      'INSERT INTO exercises (name, description) VALUES (?, ?)',
      [name.trim(), description.trim()],
    );

Future<void> updateExercise(Database db, int id, String name, String description) =>
    db.rawUpdate(
      'UPDATE exercises SET name = ?, description = ? WHERE id = ?',
      [name.trim(), description.trim(), id],
    ).then((_) {});

Future<void> deleteExercise(Database db, int id) =>
    db.rawDelete('DELETE FROM exercises WHERE id = ?', [id]).then((_) {});

Future<int> getExerciseUsageCount(Database db, int id) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) as count FROM workout_plan_exercises WHERE exercise_id = ?',
    [id],
  );
  return (rows.first['count'] as int?) ?? 0;
}
