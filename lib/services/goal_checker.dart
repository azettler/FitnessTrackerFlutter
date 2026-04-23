import 'package:sqflite/sqflite.dart';

Future<void> checkAndMarkGoalAchieved(
  Database db,
  int exerciseId,
  double weightLbs,
) async {
  final goals = await db.rawQuery(
    '''SELECT id FROM goals
       WHERE exercise_id = ? AND achieved_at IS NULL AND target_weight_lbs <= ?''',
    [exerciseId, weightLbs],
  );
  for (final goal in goals) {
    await db.rawUpdate(
      'UPDATE goals SET achieved_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), goal['id']],
    );
  }
}
