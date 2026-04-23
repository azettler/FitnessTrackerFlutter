import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/instance_repository.dart';
import '../../services/goal_checker.dart';
import '../../theme/colors.dart';

class WorkoutInstanceScreen extends StatefulWidget {
  final int instanceId;
  const WorkoutInstanceScreen({super.key, required this.instanceId});

  @override
  State<WorkoutInstanceScreen> createState() => _WorkoutInstanceScreenState();
}

class _WorkoutInstanceScreenState extends State<WorkoutInstanceScreen> {
  Database? _db;
  WorkoutInstance? _instance;
  List<WorkoutInstanceExercise> _exercises = [];
  // exerciseId → sets
  Map<int, List<WorkoutInstanceSet>> _sets = {};
  // exerciseId → expanded
  Map<int, bool> _expanded = {};
  // setId → controllers
  Map<int, TextEditingController> _repsControllers = {};
  Map<int, TextEditingController> _weightControllers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in _repsControllers.values) { c.dispose(); }
    for (final c in _weightControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    await _load();
  }

  Future<void> _load() async {
    final db = _db;
    if (db == null) return;

    final instance = await getInstanceById(db, widget.instanceId);
    if (instance == null) return;

    final exercises = await getInstanceExercises(db, widget.instanceId);
    final setsMap = <int, List<WorkoutInstanceSet>>{};
    final prefillMap = <int, Map<int, Map<String, dynamic>>>{};
    final expandedMap = <int, bool>{};
    final newRepsCtrl = <int, TextEditingController>{};
    final newWeightCtrl = <int, TextEditingController>{};

    for (final ex in exercises) {
      final sets = await getInstanceSets(db, ex.id);
      setsMap[ex.id] = sets;
      expandedMap[ex.id] = true;

      final bySetNum = <int, Map<String, dynamic>>{};
      for (int n = 1; n <= ex.targetSets; n++) {
        final prefill = await getLastLoggedSet(db, ex.exerciseId, n, instance.scheduledDate);
        if (prefill != null) bySetNum[n] = prefill;
      }
      prefillMap[ex.exerciseId] = bySetNum;

      for (final s in sets) {
        final prefillReps = prefillMap[ex.exerciseId]?[s.setNumber]?['reps'];
        final prefillWeight = prefillMap[ex.exerciseId]?[s.setNumber]?['weight_lbs'];
        newRepsCtrl[s.id] = TextEditingController(
          text: s.reps?.toString() ?? prefillReps?.toString() ?? '',
        );
        newWeightCtrl[s.id] = TextEditingController(
          text: s.weightLbs?.toString() ?? prefillWeight?.toString() ?? '',
        );
      }
    }

    // Dispose old controllers
    for (final c in _repsControllers.values) { c.dispose(); }
    for (final c in _weightControllers.values) { c.dispose(); }

    if (mounted) {
      setState(() {
        _instance = instance;
        _exercises = exercises;
        _sets = setsMap;
        _expanded = expandedMap;
        _repsControllers = newRepsCtrl;
        _weightControllers = newWeightCtrl;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSet(WorkoutInstanceExercise ex, WorkoutInstanceSet s) async {
    final db = _db;
    if (db == null) return;

    final repsText = _repsControllers[s.id]?.text ?? '';
    final weightText = _weightControllers[s.id]?.text ?? '';
    final newCompleted = !s.completed;

    final reps = int.tryParse(repsText);
    final weight = double.tryParse(weightText);

    await updateSet(db, s.id, reps: reps, weightLbs: weight, completed: newCompleted);

    if (newCompleted && weight != null) {
      await checkAndMarkGoalAchieved(db, ex.exerciseId, weight);
    }

    await recalculateInstanceStatus(db, widget.instanceId);
    await _load();
  }

  Future<void> _toggleSkipExercise(WorkoutInstanceExercise ex) async {
    final db = _db;
    if (db == null) return;
    await updateInstanceExerciseSkipped(db, ex.id, !ex.skipped);
    await recalculateInstanceStatus(db, widget.instanceId);
    await _load();
  }

  Future<void> _skipWorkout() async {
    final db = _db;
    if (db == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Skip Workout'),
        content: const Text('Mark all exercises as skipped?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final ex in _exercises) {
      await updateInstanceExerciseSkipped(db, ex.id, true);
    }
    await recalculateInstanceStatus(db, widget.instanceId);
    if (mounted) context.pop();
  }

  Color _statusColor(WorkoutInstanceStatus s) {
    switch (s) {
      case WorkoutInstanceStatus.complete:
        return AppColors.statusComplete;
      case WorkoutInstanceStatus.partial:
        return AppColors.statusPartial;
      case WorkoutInstanceStatus.pending:
        return AppColors.statusScheduled;
      case WorkoutInstanceStatus.skipped:
        return AppColors.statusSkipped;
    }
  }

  String _statusLabel(WorkoutInstanceStatus s) {
    switch (s) {
      case WorkoutInstanceStatus.complete:
        return 'Complete';
      case WorkoutInstanceStatus.partial:
        return 'Partial';
      case WorkoutInstanceStatus.pending:
        return 'Scheduled';
      case WorkoutInstanceStatus.skipped:
        return 'Skipped';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inst = _instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(inst?.workoutPlanName ?? 'Workout',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Date + status row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            inst != null
                                ? DateFormat('EEEE, MMM d').format(
                                    DateTime.parse('${inst.scheduledDate}T00:00:00'))
                                : '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                          ),
                          if (inst != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: _statusColor(inst.status)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(inst.status),
                                style: TextStyle(
                                    color: _statusColor(inst.status), fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Exercise cards
                      ..._exercises.map((ex) => _buildExerciseCard(ex)),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),

                // Skip Workout button
                Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _skipWorkout,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Skip Workout',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildExerciseCard(WorkoutInstanceExercise ex) {
    final sets = _sets[ex.id] ?? [];
    final doneCount = sets.where((s) => s.completed).length;
    final expanded = _expanded[ex.id] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        children: [
          // Exercise header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.exerciseName ?? 'Exercise',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          children: [
                            TextSpan(text: '${ex.targetSets} × ${ex.targetReps}  '),
                            TextSpan(
                              text: '$doneCount/${ex.targetSets} done',
                              style: const TextStyle(
                                  color: AppColors.statusComplete, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (doneCount == ex.targetSets && !ex.skipped)
                  const Icon(Icons.check, color: AppColors.statusComplete, size: 20),
                const SizedBox(width: 8),
                if (!ex.skipped)
                  OutlinedButton(
                    onPressed: () => _toggleSkipExercise(ex),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 13)),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _toggleSkipExercise(ex),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.statusSkipped),
                      foregroundColor: AppColors.statusSkipped,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Skipped', style: TextStyle(fontSize: 13)),
                  ),
                IconButton(
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted),
                  onPressed: () => setState(() => _expanded[ex.id] = !expanded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Set rows
          if (expanded && !ex.skipped)
            ...sets.map((s) => _buildSetRow(ex, s)),
        ],
      ),
    );
  }

  Widget _buildSetRow(WorkoutInstanceExercise ex, WorkoutInstanceSet s) {
    final repsCtrl = _repsControllers[s.id];
    final weightCtrl = _weightControllers[s.id];
    final isComplete = s.completed;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
        color: isComplete ? AppColors.statusComplete.withValues(alpha: 0.06) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text('Set ${s.setNumber}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
          Expanded(
            child: _setField(repsCtrl, isComplete),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('×', style: TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: _setField(weightCtrl, isComplete),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _toggleSet(ex, s),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isComplete ? AppColors.statusComplete : AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check,
                  color: isComplete ? Colors.white : AppColors.textSecondary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setField(TextEditingController? ctrl, bool completed) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        color: completed ? AppColors.statusComplete : AppColors.textPrimary,
        fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: completed
                ? AppColors.statusComplete.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        filled: completed,
        fillColor: completed ? AppColors.statusComplete.withValues(alpha: 0.08) : null,
      ),
    );
  }
}
