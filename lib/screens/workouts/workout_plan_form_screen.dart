import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/workout_repository.dart';
import '../../theme/colors.dart';

class WorkoutPlanFormScreen extends StatefulWidget {
  final int? planId;
  const WorkoutPlanFormScreen({super.key, this.planId});

  @override
  State<WorkoutPlanFormScreen> createState() => _WorkoutPlanFormScreenState();
}

class _WorkoutPlanFormScreenState extends State<WorkoutPlanFormScreen> {
  Database? _db;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<WorkoutPlanExercise> _exercises = [];
  bool _saving = false;

  bool get _isEditing => widget.planId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    if (_isEditing) {
      final plan = await getPlanById(_db!, widget.planId!);
      final exercises = await getPlanExercises(_db!, widget.planId!);
      if (mounted) {
        setState(() {
          _nameCtrl.text = plan?.name ?? '';
          _descCtrl.text = plan?.description ?? '';
          _exercises = exercises;
        });
      }
    }
  }

  Future<void> _pickExercises() async {
    final selectedIds = _exercises.map((e) => e.exerciseId).toList();
    final result = await context.push<List<Map<String, dynamic>>>(
      '/workouts/exercise-picker',
      extra: {'selectedIds': selectedIds},
    );
    if (result == null || !mounted) return;
    setState(() {
      _exercises = result
          .asMap()
          .entries
          .map((entry) => WorkoutPlanExercise(
                id: 0,
                workoutPlanId: widget.planId ?? 0,
                exerciseId: entry.value['exerciseId'] as int,
                sortOrder: entry.key,
                targetSets: entry.value['targetSets'] as int? ?? 3,
                targetReps: entry.value['targetReps'] as int? ?? 10,
                exerciseName: entry.value['exerciseName'] as String?,
              ))
          .toList();
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    final db = _db!;
    try {
      if (_isEditing) {
        await updatePlan(db, widget.planId!, name, _descCtrl.text.trim());
        await upsertPlanExercises(
          db,
          widget.planId!,
          _exercises
              .asMap()
              .entries
              .map((e) => PlanExerciseInput(
                    exerciseId: e.value.exerciseId,
                    sortOrder: e.key,
                    targetSets: e.value.targetSets,
                    targetReps: e.value.targetReps,
                  ))
              .toList(),
        );
        if (mounted) context.pop();
      } else {
        final newId = await createPlan(db, name, _descCtrl.text.trim());
        await upsertPlanExercises(
          db,
          newId,
          _exercises
              .asMap()
              .entries
              .map((e) => PlanExerciseInput(
                    exerciseId: e.value.exerciseId,
                    sortOrder: e.key,
                    targetSets: e.value.targetSets,
                    targetReps: e.value.targetReps,
                  ))
              .toList(),
        );
        if (mounted) context.go('/workouts/plan/$newId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Plan' : 'New Plan',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('NAME'),
          const SizedBox(height: 6),
          _field(_nameCtrl, 'e.g. Push Day'),
          const SizedBox(height: 16),
          _label('DESCRIPTION'),
          const SizedBox(height: 6),
          _field(_descCtrl, 'Optional notes', maxLines: 3),
          const SizedBox(height: 24),
          _label('EXERCISES'),
          const SizedBox(height: 8),
          if (_exercises.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _exercises.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _exerciseRow(_exercises[i], i),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _dashedButton('+ Add Exercises', _pickExercises),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8));

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      );

  Widget _exerciseRow(WorkoutPlanExercise ex, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex.exerciseName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${ex.targetSets} sets × ${ex.targetReps} reps',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: () => setState(() => _exercises.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _dashedButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5), style: BorderStyle.solid, width: 1.5),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      );
}
