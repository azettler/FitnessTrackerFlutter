import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/exercise_repository.dart';
import '../../theme/colors.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final int exerciseId;
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Database? _db;
  Exercise? _exercise;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    final ex = await getExerciseById(_db!, widget.exerciseId);
    if (mounted) setState(() => _exercise = ex);
  }

  Future<void> _delete() async {
    final db = _db;
    if (db == null) return;
    final usageCount = await getExerciseUsageCount(db, widget.exerciseId);
    if (!mounted) return;
    if (usageCount > 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Text('This exercise is used in $usageCount workout plan(s). Remove it from those plans first.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: const Text('This exercise will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await deleteExercise(db, widget.exerciseId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ex = _exercise;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ex?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context
                .push('/exercises/${widget.exerciseId}/edit')
                .then((_) => _init()),
            child: const Text('Edit',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ex == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _infoCard('NAME', ex.name),
                const SizedBox(height: 12),
                _infoCard('DESCRIPTION', ex.description.isNotEmpty ? ex.description : '—'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Delete Exercise',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoCard(String label, String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
          ],
        ),
      );
}
