import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

Future<List<WorkoutInstance>> getInstancesForDateRange(
  Database db,
  String startDate,
  String endDate,
) async {
  final rows = await db.rawQuery(
    '''SELECT wi.*, wp.name as workout_plan_name
       FROM workout_instances wi
       JOIN workout_plans wp ON wp.id = wi.workout_plan_id
       WHERE wi.scheduled_date BETWEEN ? AND ?
       ORDER BY wi.scheduled_date ASC''',
    [startDate, endDate],
  );
  return rows.map(WorkoutInstance.fromMap).toList();
}

Future<List<WorkoutInstance>> getInstancesForDate(Database db, String date) async {
  final rows = await db.rawQuery(
    '''SELECT wi.*, wp.name as workout_plan_name
       FROM workout_instances wi
       JOIN workout_plans wp ON wp.id = wi.workout_plan_id
       WHERE wi.scheduled_date = ?
       ORDER BY wi.created_at ASC''',
    [date],
  );
  return rows.map(WorkoutInstance.fromMap).toList();
}

Future<WorkoutInstance?> getInstanceById(Database db, int id) async {
  final rows = await db.rawQuery(
    '''SELECT wi.*, wp.name as workout_plan_name
       FROM workout_instances wi
       JOIN workout_plans wp ON wp.id = wi.workout_plan_id
       WHERE wi.id = ?''',
    [id],
  );
  return rows.isEmpty ? null : WorkoutInstance.fromMap(rows.first);
}

Future<List<WorkoutInstanceExercise>> getInstanceExercises(
  Database db,
  int instanceId,
) async {
  final rows = await db.rawQuery(
    '''SELECT wie.*, e.name as exercise_name, e.description as exercise_description
       FROM workout_instance_exercises wie
       JOIN exercises e ON e.id = wie.exercise_id
       WHERE wie.workout_instance_id = ?
       ORDER BY wie.sort_order ASC''',
    [instanceId],
  );
  return rows.map(WorkoutInstanceExercise.fromMap).toList();
}

Future<List<WorkoutInstanceSet>> getInstanceSets(
  Database db,
  int instanceExerciseId,
) async {
  final rows = await db.rawQuery(
    '''SELECT * FROM workout_instance_sets
       WHERE workout_instance_exercise_id = ?
       ORDER BY set_number ASC''',
    [instanceExerciseId],
  );
  return rows.map(WorkoutInstanceSet.fromMap).toList();
}

Future<void> updateInstanceStatus(
  Database db,
  int instanceId,
  WorkoutInstanceStatus status, {
  String? notes,
}) async {
  if (notes != null) {
    await db.rawUpdate(
      'UPDATE workout_instances SET status = ?, notes = ? WHERE id = ?',
      [status.value, notes, instanceId],
    );
  } else {
    await db.rawUpdate(
      'UPDATE workout_instances SET status = ? WHERE id = ?',
      [status.value, instanceId],
    );
  }
}

Future<void> updateInstanceExerciseSkipped(
  Database db,
  int instanceExerciseId,
  bool skipped,
) async {
  await db.rawUpdate(
    'UPDATE workout_instance_exercises SET skipped = ? WHERE id = ?',
    [skipped ? 1 : 0, instanceExerciseId],
  );
}

Future<void> updateSet(
  Database db,
  int setId, {
  required int? reps,
  required double? weightLbs,
  required bool completed,
}) async {
  await db.rawUpdate(
    '''UPDATE workout_instance_sets
       SET reps = ?, weight_lbs = ?, completed = ?, logged_at = ?
       WHERE id = ?''',
    [reps, weightLbs, completed ? 1 : 0, completed ? DateTime.now().toIso8601String() : null, setId],
  );
}

Future<WorkoutInstanceStatus> recalculateInstanceStatus(
  Database db,
  int instanceId,
) async {
  final exercises = await db.rawQuery(
    'SELECT id, skipped FROM workout_instance_exercises WHERE workout_instance_id = ?',
    [instanceId],
  );

  final active = exercises.where((e) => (e['skipped'] as int) == 0).toList();

  if (active.isEmpty) {
    await updateInstanceStatus(db, instanceId, WorkoutInstanceStatus.skipped);
    return WorkoutInstanceStatus.skipped;
  }

  final hasSkipped = active.length < exercises.length;
  bool anyCompleted = false;
  bool allComplete = true;

  for (final ex in active) {
    final sets = await db.rawQuery(
      'SELECT completed FROM workout_instance_sets WHERE workout_instance_exercise_id = ?',
      [ex['id']],
    );
    final done = sets.where((s) => (s['completed'] as int) == 1).length;
    if (done > 0) anyCompleted = true;
    if (done < sets.length) allComplete = false;
  }

  final status = !anyCompleted
      ? WorkoutInstanceStatus.pending
      : allComplete && !hasSkipped
          ? WorkoutInstanceStatus.complete
          : WorkoutInstanceStatus.partial;

  await updateInstanceStatus(db, instanceId, status);
  return status;
}

Future<Map<String, dynamic>?> getLastLoggedSet(
  Database db,
  int exerciseId,
  int setNumber,
  String beforeDate,
) async {
  final rows = await db.rawQuery(
    '''SELECT wis.reps, wis.weight_lbs
       FROM workout_instance_sets wis
       JOIN workout_instance_exercises wie ON wie.id = wis.workout_instance_exercise_id
       JOIN workout_instances wi ON wi.id = wie.workout_instance_id
       WHERE wie.exercise_id = ?
         AND wis.set_number = ?
         AND wis.completed = 1
         AND wi.scheduled_date < ?
       ORDER BY wi.scheduled_date DESC
       LIMIT 1''',
    [exerciseId, setNumber, beforeDate],
  );
  return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
}
