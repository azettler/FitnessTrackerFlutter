import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/goal_repository.dart';
import '../../theme/colors.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  Database? _db;
  List<Goal> _goals = [];
  // exerciseId → current best weight
  Map<int, double?> _currentBest = {};
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
    final goals = await getAllGoals(db);
    final bestMap = <int, double?>{};
    for (final g in goals) {
      if (!bestMap.containsKey(g.exerciseId)) {
        bestMap[g.exerciseId] = await getCurrentBestWeight(db, g.exerciseId);
      }
    }
    if (mounted) {
      setState(() {
        _goals = goals;
        _currentBest = bestMap;
        _loading = false;
      });
    }
  }

  Future<void> _delete(Goal goal) async {
    final db = _db;
    if (db == null) return;
    await deleteGoal(db, goal.id);
    await _load();
  }

  double _progress(Goal goal) {
    final baseline = goal.baselineWeightLbs;
    final current = _currentBest[goal.exerciseId];
    if (baseline == null || current == null) return 0.0;
    final range = goal.targetWeightLbs - baseline;
    if (range <= 0) return 1.0;
    return ((current - baseline) / range).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final active = _goals.where((g) => g.achievedAt == null).toList();
    final achieved = _goals.where((g) => g.achievedAt != null).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Goals', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/goals/new').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? const Center(
                  child: Text('No goals yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (active.isNotEmpty) ...[
                      _sectionLabel('ACTIVE (${active.length})'),
                      const SizedBox(height: 8),
                      ...active.map((g) => _goalCard(g)),
                    ],
                    if (achieved.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel('ACHIEVED (${achieved.length})'),
                      const SizedBox(height: 8),
                      ...achieved.map((g) => _goalCard(g)),
                    ],
                  ],
                ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8));

  Widget _goalCard(Goal goal) {
    final progress = _progress(goal);
    final current = _currentBest[goal.exerciseId];
    final baseline = goal.baselineWeightLbs;
    final isAchieved = goal.achievedAt != null;

    return GestureDetector(
      onLongPress: () => _confirmDelete(goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal.exerciseName ?? '',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text('Target: ${goal.targetWeightLbs.toStringAsFixed(0)} lbs',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            if (goal.dueDate != null)
              Text(
                'Due: ${DateFormat('MMM d, yyyy').format(DateTime.parse('${goal.dueDate}T00:00:00'))}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                    isAchieved ? AppColors.statusComplete : AppColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  baseline != null ? '${baseline.toStringAsFixed(0)} lbs' : '— lbs',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${goal.targetWeightLbs.toStringAsFixed(0)} lbs',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (current != null && !isAchieved) ...[
              const SizedBox(height: 4),
              Text('Current best: ${current.toStringAsFixed(0)} lbs',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            const SizedBox(height: 4),
            const Text('Long-press to delete',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Remove goal for ${goal.exerciseName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true) await _delete(goal);
  }
}
