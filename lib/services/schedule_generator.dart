import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../repositories/schedule_repository.dart';

final _fmt = DateFormat('yyyy-MM-dd');

String _fmtDate(DateTime d) => _fmt.format(d);

// DB stores JS day convention (0=Sun,1=Mon,…,6=Sat); convert Dart weekday to match
int _toJsDay(DateTime d) => d.weekday == 7 ? 0 : d.weekday;

bool _matchesRecurrence(DateTime date, dynamic schedule) {
  final recurrenceType = schedule['recurrence_type'] as String;
  final startDate = DateTime.parse('${schedule['start_date']}T00:00:00');
  switch (recurrenceType) {
    case 'daily':
      return true;
    case 'weekly':
      final diff = date.difference(startDate).inDays;
      return diff >= 0 && diff % 7 == 0;
    case 'specific_days':
      final allowed = ((schedule['days_of_week'] as String?) ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toSet();
      return allowed.contains(_toJsDay(date));
    default:
      return false;
  }
}

/// Generates workout instances for all active schedules up to 1 year out.
/// Idempotent — uses INSERT OR IGNORE on the UNIQUE constraint.
Future<int> generateInstances(Database db, {DateTime? today}) async {
  final now = today ?? DateTime.now();
  final todayStr = _fmtDate(now);
  final horizon = DateTime(now.year + 1, now.month, now.day);

  final schedules = await getAllActiveSchedules(db, todayStr);
  int created = 0;

  for (final schedule in schedules) {
    final startDate = DateTime.parse('${schedule.startDate}T00:00:00');
    final rangeStart = startDate.isAfter(now) ? startDate : now;
    final rangeEnd = schedule.endDate != null
        ? () {
            final ed = DateTime.parse('${schedule.endDate}T00:00:00');
            return ed.isBefore(horizon) ? ed : horizon;
          }()
        : horizon;

    if (rangeStart.isAfter(rangeEnd)) continue;

    // Fetch plan exercises once per schedule
    final planExercises = await db.rawQuery(
      '''SELECT exercise_id, sort_order, target_sets, target_reps
         FROM workout_plan_exercises
         WHERE workout_plan_id = ?
         ORDER BY sort_order ASC''',
      [schedule.workoutPlanId],
    );

    await db.transaction((txn) async {
      DateTime cur = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      while (!cur.isAfter(rangeEnd)) {
        final scheduleMap = {
          'recurrence_type': schedule.recurrenceType,
          'days_of_week': schedule.daysOfWeek,
          'start_date': schedule.startDate,
        };
        if (_matchesRecurrence(cur, scheduleMap)) {
          final dateStr = _fmtDate(cur);
          final result = await txn.rawInsert(
            '''INSERT OR IGNORE INTO workout_instances
                 (workout_plan_id, workout_schedule_id, scheduled_date, status)
               VALUES (?, ?, ?, 'pending')''',
            [schedule.workoutPlanId, schedule.id, dateStr],
          );

          // INSERT OR IGNORE returns 0 on conflict — check via a query
          final check = await txn.rawQuery(
            'SELECT id FROM workout_instances WHERE workout_plan_id = ? AND scheduled_date = ?',
            [schedule.workoutPlanId, dateStr],
          );
          if (check.isEmpty) {
            cur = cur.add(const Duration(days: 1));
            continue;
          }

          // Determine if this was a new insertion by checking result rowid
          final instanceId = result;
          if (instanceId == 0) {
            // Already existed
            cur = cur.add(const Duration(days: 1));
            continue;
          }

          created++;

          for (final pe in planExercises) {
            final ieResult = await txn.rawInsert(
              '''INSERT OR IGNORE INTO workout_instance_exercises
                   (workout_instance_id, exercise_id, sort_order, target_sets, target_reps, skipped)
                 VALUES (?, ?, ?, ?, ?, 0)''',
              [instanceId, pe['exercise_id'], pe['sort_order'], pe['target_sets'], pe['target_reps']],
            );

            if (ieResult == 0) continue;

            final targetSets = pe['target_sets'] as int;
            for (int setNum = 1; setNum <= targetSets; setNum++) {
              await txn.rawInsert(
                '''INSERT OR IGNORE INTO workout_instance_sets
                     (workout_instance_exercise_id, set_number, completed)
                   VALUES (?, ?, 0)''',
                [ieResult, setNum],
              );
            }
          }
        }
        cur = cur.add(const Duration(days: 1));
      }
    });
  }

  return created;
}
