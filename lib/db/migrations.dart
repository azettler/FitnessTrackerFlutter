import 'package:sqflite/sqflite.dart';

class DbMigrations {
  static const int currentVersion = 3;

  // Full current schema for fresh installs (includes all columns at latest version)
  static const List<String> _currentSchema = [
    '''CREATE TABLE IF NOT EXISTS exercises (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT    NOT NULL UNIQUE COLLATE NOCASE,
      description TEXT    NOT NULL DEFAULT '',
      created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
    )''',
    '''CREATE TABLE IF NOT EXISTS workout_plans (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT    NOT NULL,
      description TEXT    NOT NULL DEFAULT '',
      created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
    )''',
    '''CREATE TABLE IF NOT EXISTS workout_plan_exercises (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_plan_id INTEGER NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
      exercise_id     INTEGER NOT NULL REFERENCES exercises(id),
      sort_order      INTEGER NOT NULL DEFAULT 0,
      target_sets     INTEGER NOT NULL DEFAULT 3,
      target_reps     INTEGER NOT NULL DEFAULT 10,
      UNIQUE (workout_plan_id, exercise_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS workout_schedules (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_plan_id INTEGER NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
      recurrence_type TEXT    NOT NULL CHECK(recurrence_type IN ('daily','weekly','specific_days')),
      days_of_week    TEXT,
      start_date      TEXT    NOT NULL,
      end_date        TEXT,
      created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
    )''',
    '''CREATE TABLE IF NOT EXISTS workout_instances (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_plan_id     INTEGER NOT NULL REFERENCES workout_plans(id),
      workout_schedule_id INTEGER REFERENCES workout_schedules(id) ON DELETE SET NULL,
      scheduled_date      TEXT    NOT NULL,
      status              TEXT    NOT NULL DEFAULT 'pending'
                                   CHECK(status IN ('pending','complete','partial','skipped')),
      notes               TEXT,
      created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
      UNIQUE (workout_plan_id, scheduled_date)
    )''',
    '''CREATE TABLE IF NOT EXISTS workout_instance_exercises (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_instance_id INTEGER NOT NULL REFERENCES workout_instances(id) ON DELETE CASCADE,
      exercise_id         INTEGER NOT NULL REFERENCES exercises(id),
      sort_order          INTEGER NOT NULL DEFAULT 0,
      target_sets         INTEGER NOT NULL,
      target_reps         INTEGER NOT NULL,
      skipped             INTEGER NOT NULL DEFAULT 0 CHECK(skipped IN (0,1)),
      UNIQUE (workout_instance_id, exercise_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS workout_instance_sets (
      id                           INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_instance_exercise_id INTEGER NOT NULL
                                     REFERENCES workout_instance_exercises(id) ON DELETE CASCADE,
      set_number                   INTEGER NOT NULL,
      reps                         INTEGER,
      weight_lbs                   REAL,
      completed                    INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1)),
      logged_at                    TEXT,
      UNIQUE (workout_instance_exercise_id, set_number)
    )''',
    '''CREATE TABLE IF NOT EXISTS exempt_days (
      id     INTEGER PRIMARY KEY AUTOINCREMENT,
      date   TEXT    NOT NULL UNIQUE,
      reason TEXT
    )''',
    '''CREATE TABLE IF NOT EXISTS goals (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      exercise_id         INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
      target_weight_lbs   REAL    NOT NULL,
      baseline_weight_lbs REAL,
      due_date            TEXT,
      created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
      achieved_at         TEXT
    )''',
    '''CREATE TABLE IF NOT EXISTS progress_photos (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      date       TEXT NOT NULL,
      file_uri   TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )''',
    'CREATE INDEX IF NOT EXISTS idx_workout_instances_date ON workout_instances(scheduled_date)',
    'CREATE INDEX IF NOT EXISTS idx_workout_instances_schedule ON workout_instances(workout_schedule_id)',
    'CREATE INDEX IF NOT EXISTS idx_workout_instance_exercises_instance ON workout_instance_exercises(workout_instance_id)',
    'CREATE INDEX IF NOT EXISTS idx_workout_instance_sets_exercise ON workout_instance_sets(workout_instance_exercise_id)',
    'CREATE INDEX IF NOT EXISTS idx_goals_exercise ON goals(exercise_id)',
    'CREATE INDEX IF NOT EXISTS idx_progress_photos_date ON progress_photos(date)',
  ];

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');
    for (final stmt in _currentSchema) {
      await db.execute(stmt);
    }
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('PRAGMA foreign_keys = ON');
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE goals ADD COLUMN baseline_weight_lbs REAL');
    }
    if (oldVersion < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS progress_photos (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        date       TEXT NOT NULL,
        file_uri   TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_progress_photos_date ON progress_photos(date)',
      );
    }
  }
}
