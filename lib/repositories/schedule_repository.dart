import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

Future<List<WorkoutSchedule>> getSchedulesForPlan(Database db, int planId) async {
  final rows = await db.rawQuery(
    'SELECT * FROM workout_schedules WHERE workout_plan_id = ? ORDER BY start_date ASC',
    [planId],
  );
  return rows.map(WorkoutSchedule.fromMap).toList();
}

Future<List<WorkoutSchedule>> getAllActiveSchedules(Database db, String today) async {
  final rows = await db.rawQuery(
    'SELECT * FROM workout_schedules WHERE end_date IS NULL OR end_date >= ?',
    [today],
  );
  return rows.map(WorkoutSchedule.fromMap).toList();
}

Future<WorkoutSchedule?> getScheduleById(Database db, int id) async {
  final rows = await db.rawQuery('SELECT * FROM workout_schedules WHERE id = ?', [id]);
  return rows.isEmpty ? null : WorkoutSchedule.fromMap(rows.first);
}

Future<int> createSchedule(
  Database db, {
  required int workoutPlanId,
  required String recurrenceType,
  String? daysOfWeek,
  required String startDate,
  String? endDate,
}) =>
    db.rawInsert(
      '''INSERT INTO workout_schedules
           (workout_plan_id, recurrence_type, days_of_week, start_date, end_date)
         VALUES (?, ?, ?, ?, ?)''',
      [workoutPlanId, recurrenceType, daysOfWeek, startDate, endDate],
    );

Future<void> updateSchedule(
  Database db,
  int id, {
  required String recurrenceType,
  String? daysOfWeek,
  required String startDate,
  String? endDate,
}) async {
  await db.transaction((txn) async {
    await txn.rawUpdate(
      '''UPDATE workout_schedules
         SET recurrence_type = ?, days_of_week = ?, start_date = ?, end_date = ?
         WHERE id = ?''',
      [recurrenceType, daysOfWeek, startDate, endDate, id],
    );
    if (endDate != null) {
      await txn.rawDelete(
        '''DELETE FROM workout_instances
           WHERE workout_schedule_id = ? AND status = 'pending' AND scheduled_date > ?''',
        [id, endDate],
      );
    }
  });
}

Future<void> deleteSchedule(Database db, int id) async {
  await db.transaction((txn) async {
    await txn.rawDelete(
      '''DELETE FROM workout_instances
         WHERE workout_schedule_id = ? AND status = 'pending' AND scheduled_date >= date('now')''',
      [id],
    );
    await txn.rawDelete('DELETE FROM workout_schedules WHERE id = ?', [id]);
  });
}
