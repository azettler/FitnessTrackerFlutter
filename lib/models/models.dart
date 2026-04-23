enum DayStatus { complete, partial, scheduled, skipped, exempt, neutral }

enum WorkoutInstanceStatus { pending, complete, partial, skipped }

extension WorkoutInstanceStatusExt on WorkoutInstanceStatus {
  String get value => name;
  static WorkoutInstanceStatus fromString(String s) =>
      WorkoutInstanceStatus.values.firstWhere((e) => e.name == s);
}

// ─── Exercise ────────────────────────────────────────────────────────────────

class Exercise {
  final int id;
  final String name;
  final String description;
  final String createdAt;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
        id: m['id'] as int,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        createdAt: m['created_at'] as String? ?? '',
      );
}

// ─── WorkoutPlan ──────────────────────────────────────────────────────────────

class WorkoutPlan {
  final int id;
  final String name;
  final String description;
  final String createdAt;

  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  factory WorkoutPlan.fromMap(Map<String, dynamic> m) => WorkoutPlan(
        id: m['id'] as int,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        createdAt: m['created_at'] as String? ?? '',
      );
}

// ─── WorkoutPlanExercise ──────────────────────────────────────────────────────

class WorkoutPlanExercise {
  final int id;
  final int workoutPlanId;
  final int exerciseId;
  final int sortOrder;
  final int targetSets;
  final int targetReps;
  final String? exerciseName;
  final String? exerciseDescription;

  const WorkoutPlanExercise({
    required this.id,
    required this.workoutPlanId,
    required this.exerciseId,
    required this.sortOrder,
    required this.targetSets,
    required this.targetReps,
    this.exerciseName,
    this.exerciseDescription,
  });

  factory WorkoutPlanExercise.fromMap(Map<String, dynamic> m) => WorkoutPlanExercise(
        id: m['id'] as int,
        workoutPlanId: m['workout_plan_id'] as int,
        exerciseId: m['exercise_id'] as int,
        sortOrder: m['sort_order'] as int,
        targetSets: m['target_sets'] as int,
        targetReps: m['target_reps'] as int,
        exerciseName: m['exercise_name'] as String?,
        exerciseDescription: m['exercise_description'] as String?,
      );
}

// ─── WorkoutSchedule ──────────────────────────────────────────────────────────

class WorkoutSchedule {
  final int id;
  final int workoutPlanId;
  final String recurrenceType; // 'daily' | 'weekly' | 'specific_days'
  final String? daysOfWeek;   // comma-separated JS days (0=Sun…6=Sat)
  final String startDate;     // YYYY-MM-DD
  final String? endDate;
  final String createdAt;

  const WorkoutSchedule({
    required this.id,
    required this.workoutPlanId,
    required this.recurrenceType,
    this.daysOfWeek,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  factory WorkoutSchedule.fromMap(Map<String, dynamic> m) => WorkoutSchedule(
        id: m['id'] as int,
        workoutPlanId: m['workout_plan_id'] as int,
        recurrenceType: m['recurrence_type'] as String,
        daysOfWeek: m['days_of_week'] as String?,
        startDate: m['start_date'] as String,
        endDate: m['end_date'] as String?,
        createdAt: m['created_at'] as String? ?? '',
      );

  String get humanLabel {
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    switch (recurrenceType) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        final d = DateTime.parse('${startDate}T00:00:00');
        return 'Every ${dayNames[d.weekday % 7]}';
      case 'specific_days':
        final days = (daysOfWeek ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => dayNames[int.parse(s)])
            .join(', ');
        return days.isEmpty ? 'Specific days' : days;
      default:
        return recurrenceType;
    }
  }
}

// ─── WorkoutInstance ──────────────────────────────────────────────────────────

class WorkoutInstance {
  final int id;
  final int workoutPlanId;
  final int? workoutScheduleId;
  final String scheduledDate;
  final WorkoutInstanceStatus status;
  final String? notes;
  final String createdAt;
  final String? workoutPlanName;

  const WorkoutInstance({
    required this.id,
    required this.workoutPlanId,
    this.workoutScheduleId,
    required this.scheduledDate,
    required this.status,
    this.notes,
    required this.createdAt,
    this.workoutPlanName,
  });

  factory WorkoutInstance.fromMap(Map<String, dynamic> m) => WorkoutInstance(
        id: m['id'] as int,
        workoutPlanId: m['workout_plan_id'] as int,
        workoutScheduleId: m['workout_schedule_id'] as int?,
        scheduledDate: m['scheduled_date'] as String,
        status: WorkoutInstanceStatusExt.fromString(m['status'] as String),
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String? ?? '',
        workoutPlanName: m['workout_plan_name'] as String?,
      );
}

// ─── WorkoutInstanceExercise ──────────────────────────────────────────────────

class WorkoutInstanceExercise {
  final int id;
  final int workoutInstanceId;
  final int exerciseId;
  final int sortOrder;
  final int targetSets;
  final int targetReps;
  final bool skipped;
  final String? exerciseName;
  final String? exerciseDescription;

  const WorkoutInstanceExercise({
    required this.id,
    required this.workoutInstanceId,
    required this.exerciseId,
    required this.sortOrder,
    required this.targetSets,
    required this.targetReps,
    required this.skipped,
    this.exerciseName,
    this.exerciseDescription,
  });

  factory WorkoutInstanceExercise.fromMap(Map<String, dynamic> m) =>
      WorkoutInstanceExercise(
        id: m['id'] as int,
        workoutInstanceId: m['workout_instance_id'] as int,
        exerciseId: m['exercise_id'] as int,
        sortOrder: m['sort_order'] as int,
        targetSets: m['target_sets'] as int,
        targetReps: m['target_reps'] as int,
        skipped: (m['skipped'] as int) == 1,
        exerciseName: m['exercise_name'] as String?,
        exerciseDescription: m['exercise_description'] as String?,
      );
}

// ─── WorkoutInstanceSet ───────────────────────────────────────────────────────

class WorkoutInstanceSet {
  final int id;
  final int workoutInstanceExerciseId;
  final int setNumber;
  final int? reps;
  final double? weightLbs;
  final bool completed;
  final String? loggedAt;

  const WorkoutInstanceSet({
    required this.id,
    required this.workoutInstanceExerciseId,
    required this.setNumber,
    this.reps,
    this.weightLbs,
    required this.completed,
    this.loggedAt,
  });

  factory WorkoutInstanceSet.fromMap(Map<String, dynamic> m) => WorkoutInstanceSet(
        id: m['id'] as int,
        workoutInstanceExerciseId: m['workout_instance_exercise_id'] as int,
        setNumber: m['set_number'] as int,
        reps: m['reps'] as int?,
        weightLbs: (m['weight_lbs'] as num?)?.toDouble(),
        completed: (m['completed'] as int) == 1,
        loggedAt: m['logged_at'] as String?,
      );
}

// ─── ExemptDay ────────────────────────────────────────────────────────────────

class ExemptDay {
  final int id;
  final String date;
  final String? reason;

  const ExemptDay({required this.id, required this.date, this.reason});

  factory ExemptDay.fromMap(Map<String, dynamic> m) => ExemptDay(
        id: m['id'] as int,
        date: m['date'] as String,
        reason: m['reason'] as String?,
      );
}

// ─── Goal ─────────────────────────────────────────────────────────────────────

class Goal {
  final int id;
  final int exerciseId;
  final double targetWeightLbs;
  final double? baselineWeightLbs;
  final String? dueDate;
  final String createdAt;
  final String? achievedAt;
  final String? exerciseName;

  const Goal({
    required this.id,
    required this.exerciseId,
    required this.targetWeightLbs,
    this.baselineWeightLbs,
    this.dueDate,
    required this.createdAt,
    this.achievedAt,
    this.exerciseName,
  });

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as int,
        exerciseId: m['exercise_id'] as int,
        targetWeightLbs: (m['target_weight_lbs'] as num).toDouble(),
        baselineWeightLbs: (m['baseline_weight_lbs'] as num?)?.toDouble(),
        dueDate: m['due_date'] as String?,
        createdAt: m['created_at'] as String? ?? '',
        achievedAt: m['achieved_at'] as String?,
        exerciseName: m['exercise_name'] as String?,
      );

  double get progressFraction {
    final baseline = baselineWeightLbs;
    if (baseline == null) return 0.0;
    final range = targetWeightLbs - baseline;
    if (range <= 0) return 1.0;
    return ((targetWeightLbs - baseline) / range).clamp(0.0, 1.0);
  }
}

// ─── ProgressPhoto ────────────────────────────────────────────────────────────

class ProgressPhoto {
  final int id;
  final String date;
  final String fileUri;
  final String createdAt;

  const ProgressPhoto({
    required this.id,
    required this.date,
    required this.fileUri,
    required this.createdAt,
  });

  factory ProgressPhoto.fromMap(Map<String, dynamic> m) => ProgressPhoto(
        id: m['id'] as int,
        date: m['date'] as String,
        fileUri: m['file_uri'] as String,
        createdAt: m['created_at'] as String? ?? '',
      );
}
