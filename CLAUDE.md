# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install / sync dependencies
flutter pub get

# Run on a connected device or simulator
flutter run

# Type-check and lint
flutter analyze

# Build iOS (requires Mac + Xcode)
flutter build ipa
```

Flutter SDK is at `C:\flutter\bin\flutter.bat` on this machine — the `flutter` command is not on the system PATH, so invoke it directly or via PowerShell:
```powershell
& "C:\flutter\bin\flutter.bat" <command>
```

There are no automated tests in this project.

---

## Architecture Overview

This is a Flutter rewrite of the React Native **FitnessTracker** app (`b:\Aaron Z\Source\FitnessTracker`). The RN version is the reference implementation — match its feature set and data model. All data is stored locally in SQLite via `sqflite`; there is no backend.

### Entry point flow
`lib/main.dart` → `FitnessTrackerApp` (MaterialApp.router) → `router` (go_router) → `ScaffoldWithNav` (bottom tab shell) → tab screens

### Layer structure

```
lib/
  db/            database.dart (singleton AppDatabase) + migrations.dart
  models/        models.dart — all domain types (single source of truth)
  repositories/  one file per entity, take a Database as first arg
  services/      pure business logic (schedule generation, day status, etc.)
  screens/       organised by tab: calendar/, workouts/, exercises/, goals/, reports/, progress/
  widgets/       shared UI: common/
  navigation/    router.dart (go_router config)
  theme/         colors.dart (AppColors) + theme.dart (buildAppTheme)
  main.dart
```

---

## Navigation

Uses `go_router` with a `StatefulShellRoute.indexedStack` — 6 tabs, each an isolated branch with its own navigation stack. The shell widget is `ScaffoldWithNav` (`lib/widgets/common/scaffold_with_nav.dart`).

| Tab | Root path | Key screens |
|-----|-----------|-------------|
| Calendar | `/calendar` | → `/calendar/day/:date` → `/calendar/day/:date/instance/:id` |
| Workouts | `/workouts` | → `/workouts/plan/:id` → form, schedule/form, instance |
| Exercises | `/exercises` | → `/:id`, `/new` |
| Goals | `/goals` | → `/new`, `/:id/edit` |
| Reports | `/reports` | → `/reports/settings` |
| Progress | `/progress` | → `/progress/viewer` |

Pass complex objects between screens via `extra` (go_router's typed extra field), not path/query params. `PhotoViewerScreen` receives `{ photos: List<Map>, initialIndex: int }` via `extra`.

---

## Database

- **Driver:** `sqflite` — use `DatabaseFactory` / `openDatabase`, migrations via sqflite's native `version` + `onUpgrade`.
- **Singleton pattern:** `AppDatabase` in `lib/db/database.dart` with an `instance` getter and a `reset()` method (needed for DB import — close before overwriting the file).
- **Schema version:** tracked by sqflite's built-in versioning (not a `_meta` table like the RN app). Bump `version:` in `openDatabase` and add a case to `onUpgrade`.
- **Date storage:** always `YYYY-MM-DD` strings. Format with `intl`'s `DateFormat('yyyy-MM-dd')`.
- **Migrations:** `lib/db/migrations.dart` — called from `onUpgrade` in `database.dart`.

### Domain model (mirrors RN app exactly)

```
Exercise
WorkoutPlan → WorkoutPlanExercise  (ordered, target_sets + target_reps)
    ↓
WorkoutSchedule  (recurrence: specific_days only — days_of_week CSV of 0–6)
    ↓ generates
WorkoutInstance  (status: pending | partial | complete | skipped)
    ↓
WorkoutInstanceExercise  (skipped: bool — never deleted, preserves history)
    ↓
WorkoutInstanceSet  (reps?, weightLbs? — null = not yet logged)

ExemptDay        (YYYY-MM-DD, decoupled from instances)
Goal             (exerciseId, targetWeightLbs, baselineWeightLbs, dueDate?, achievedAt?)
ProgressPhoto    (date YYYY-MM-DD, fileUri — absolute path in app documents dir)
```

All model classes go in `lib/models/models.dart`.

---

## Key services to implement

### `schedule_generator.dart` — `generateInstances(db)`
Mirror the RN logic: for each active schedule, expand dates from `start_date` to `today + 365 days`, match by `days_of_week` CSV, `INSERT OR IGNORE` instances, then seed `workout_instance_exercises` and `workout_instance_sets`. Run on app launch via `WidgetsBinding.instance.addPostFrameCallback` after the first frame.

### `day_status_calculator.dart` — `computeDayStatus(date, instances, exemptDays)`
Priority: `exempt` → `neutral` → `complete` → `partial` → `scheduled`. Used by both Calendar and Reports screens. Returns one of 5 status values that map to `AppColors.statusComplete/partial/scheduled/skipped/neutral`.

### `goal_checker.dart` — `checkAndMarkGoalAchieved(db, exerciseId, weightLbs)`
Called after every set save. Queries unachieved goals for the exercise; marks `achieved_at` if `weightLbs >= targetWeightLbs`.

### `photo_service.dart`
Use `image_picker` to capture from camera or library. Copy to `getApplicationDocumentsDirectory() + '/progress/'` for persistence. Store the permanent path in the DB. `deletePhotoFile` should be idempotent.

---

## Theme

`AppColors` in `lib/theme/colors.dart` is the single source of truth for colours:
- `primary: #1A1A2E`, `accent: #E94560`, `background: #F5F5F5`, `surface: #FFFFFF`
- Status colours: `statusComplete` (green), `statusPartial` (amber), `statusScheduled` (red), `statusSkipped` (purple), `statusNeutral` (grey)

`buildAppTheme()` in `lib/theme/theme.dart` configures `MaterialApp`'s theme. Use `useMaterial3: true`.

---

## Settings / DB import-export

Located at **Reports tab → Settings**. Pattern (mirror OysterTrackerFlutter):
- **Export:** checkpoint WAL (`PRAGMA wal_checkpoint(TRUNCATE)`), copy `.db` to temp, share via `share_plus`.
- **Import:** call `AppDatabase.reset()`, delete `-wal`/`-shm` sidecars, copy picked file over DB path, reopen singleton.
