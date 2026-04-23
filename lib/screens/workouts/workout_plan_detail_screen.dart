import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/schedule_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../theme/colors.dart';

class WorkoutPlanDetailScreen extends StatefulWidget {
  final int planId;
  const WorkoutPlanDetailScreen({super.key, required this.planId});

  @override
  State<WorkoutPlanDetailScreen> createState() => _WorkoutPlanDetailScreenState();
}

class _WorkoutPlanDetailScreenState extends State<WorkoutPlanDetailScreen> {
  Database? _db;
  WorkoutPlan? _plan;
  List<WorkoutPlanExercise> _exercises = [];
  List<WorkoutSchedule> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    await _load();
  }

  Future<void> _load() async {
    final db = _db;
    if (db == null) return;
    final plan = await getPlanById(db, widget.planId);
    final exercises = await getPlanExercises(db, widget.planId);
    final schedules = await getSchedulesForPlan(db, widget.planId);
    if (mounted) {
      setState(() {
        _plan = plan;
        _exercises = exercises;
        _schedules = schedules;
        _loading = false;
      });
    }
  }

  Future<void> _deletePlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text('This will also remove all schedules and instances. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await deletePlan(_db!, widget.planId);
    if (mounted) context.pop();
  }

  String _scheduleRange(WorkoutSchedule s) {
    final start = _fmtDate(s.startDate);
    final end = s.endDate != null ? ' · Until ${_fmtDate(s.endDate!)}' : '';
    return 'From $start$end';
  }

  String _fmtDate(String iso) {
    final d = DateTime.parse('${iso}T00:00:00');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_plan?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context
                .push('/workouts/plan/${widget.planId}/form')
                .then((_) => _load()),
            child: const Text('Edit', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Description
                if (_plan?.description.isNotEmpty == true)
                  _card(Text(_plan!.description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 15))),

                const SizedBox(height: 20),

                // Exercises section
                _sectionLabel('EXERCISES (${_exercises.length})'),
                const SizedBox(height: 8),
                if (_exercises.isEmpty)
                  const Text('No exercises added.',
                      style: TextStyle(color: AppColors.textMuted))
                else
                  _card(Column(
                    children: [
                      for (int i = 0; i < _exercises.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        _exerciseRow(_exercises[i], i + 1),
                      ]
                    ],
                  )),

                const SizedBox(height: 20),

                // Schedules section
                _sectionLabel('SCHEDULES (${_schedules.length})'),
                const SizedBox(height: 8),
                ..._schedules.map((s) => GestureDetector(
                      onTap: () => context
                          .push('/workouts/plan/${widget.planId}/schedule/form',
                              extra: {'scheduleId': s.id})
                          .then((_) => _load()),
                      child: _card(Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.humanLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(_scheduleRange(s),
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        ],
                      )),
                    )),

                const SizedBox(height: 8),
                _dashedButton(
                  '+ Add Schedule',
                  () => context
                      .push('/workouts/plan/${widget.planId}/schedule/form')
                      .then((_) => _load()),
                ),

                const SizedBox(height: 24),

                // Delete plan
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _deletePlan,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Delete Plan',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: child,
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8),
      );

  Widget _exerciseRow(WorkoutPlanExercise ex, int index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$index',
                  style: const TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.exerciseName ?? '',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text('${ex.targetSets} sets × ${ex.targetReps} reps',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dashedButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5),
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      );
}
