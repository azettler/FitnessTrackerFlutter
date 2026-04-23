import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

Future<List<Goal>> getAllGoals(Database db) async {
  final rows = await db.rawQuery(
    '''SELECT g.*, e.name as exercise_name
       FROM goals g
       JOIN exercises e ON e.id = g.exercise_id
       ORDER BY g.achieved_at IS NOT NULL ASC, g.created_at DESC''',
  );
  return rows.map(Goal.fromMap).toList();
}

Future<Goal?> getGoalById(Database db, int id) async {
  final rows = await db.rawQuery(
    '''SELECT g.*, e.name as exercise_name
       FROM goals g
       JOIN exercises e ON e.id = g.exercise_id
       WHERE g.id = ?''',
    [id],
  );
  return rows.isEmpty ? null : Goal.fromMap(rows.first);
}

Future<int> createGoal(
  Database db, {
  required int exerciseId,
  required double targetWeightLbs,
  String? dueDate,
  double? baselineWeightLbs,
}) =>
    db.rawInsert(
      '''INSERT INTO goals (exercise_id, target_weight_lbs, due_date, baseline_weight_lbs)
         VALUES (?, ?, ?, ?)''',
      [exerciseId, targetWeightLbs, dueDate, baselineWeightLbs],
    );

Future<void> deleteGoal(Database db, int id) async {
  await db.rawDelete('DELETE FROM goals WHERE id = ?', [id]);
}

Future<double?> getBestWeightForExercise(Database db, int exerciseId) async {
  final rows = await db.rawQuery(
    '''SELECT MAX(wis.weight_lbs) as max_weight
       FROM workout_instance_sets wis
       JOIN workout_instance_exercises wie ON wie.id = wis.workout_instance_exercise_id
       WHERE wie.exercise_id = ? AND wis.completed = 1 AND wis.weight_lbs IS NOT NULL''',
    [exerciseId],
  );
  return (rows.first['max_weight'] as num?)?.toDouble();
}

Future<double?> getCurrentBestWeight(Database db, int exerciseId) =>
    getBestWeightForExercise(db, exerciseId);
