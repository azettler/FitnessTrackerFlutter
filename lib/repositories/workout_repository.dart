import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

// ─── Plans ────────────────────────────────────────────────────────────────────

Future<List<WorkoutPlan>> getAllPlans(Database db) async {
  final rows = await db.rawQuery('SELECT * FROM workout_plans ORDER BY name ASC');
  return rows.map(WorkoutPlan.fromMap).toList();
}

Future<WorkoutPlan?> getPlanById(Database db, int id) async {
  final rows = await db.rawQuery('SELECT * FROM workout_plans WHERE id = ?', [id]);
  return rows.isEmpty ? null : WorkoutPlan.fromMap(rows.first);
}

Future<List<WorkoutPlanExercise>> getPlanExercises(Database db, int planId) async {
  final rows = await db.rawQuery(
    '''SELECT wpe.*, e.name as exercise_name, e.description as exercise_description
       FROM workout_plan_exercises wpe
       JOIN exercises e ON e.id = wpe.exercise_id
       WHERE wpe.workout_plan_id = ?
       ORDER BY wpe.sort_order ASC''',
    [planId],
  );
  return rows.map(WorkoutPlanExercise.fromMap).toList();
}

Future<int> createPlan(Database db, String name, String description) =>
    db.rawInsert(
      'INSERT INTO workout_plans (name, description) VALUES (?, ?)',
      [name.trim(), description.trim()],
    );

Future<void> updatePlan(Database db, int id, String name, String description) async {
  await db.rawUpdate(
    'UPDATE workout_plans SET name = ?, description = ? WHERE id = ?',
    [name.trim(), description.trim(), id],
  );
}

Future<void> deletePlan(Database db, int id) async {
  await db.rawDelete('DELETE FROM workout_plans WHERE id = ?', [id]);
}

// ─── Plan exercises ───────────────────────────────────────────────────────────

class PlanExerciseInput {
  final int exerciseId;
  final int sortOrder;
  final int targetSets;
  final int targetReps;
  const PlanExerciseInput({
    required this.exerciseId,
    required this.sortOrder,
    required this.targetSets,
    required this.targetReps,
  });
}

Future<void> upsertPlanExercises(
  Database db,
  int planId,
  List<PlanExerciseInput> exercises,
) async {
  await db.transaction((txn) async {
    await txn.rawDelete(
      'DELETE FROM workout_plan_exercises WHERE workout_plan_id = ?',
      [planId],
    );
    for (final ex in exercises) {
      await txn.rawInsert(
        '''INSERT INTO workout_plan_exercises
             (workout_plan_id, exercise_id, sort_order, target_sets, target_reps)
           VALUES (?, ?, ?, ?, ?)''',
        [planId, ex.exerciseId, ex.sortOrder, ex.targetSets, ex.targetReps],
      );
    }
  });
}
