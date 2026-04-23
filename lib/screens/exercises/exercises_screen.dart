import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/exercise_repository.dart';
import '../../theme/colors.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  Database? _db;
  List<Exercise> _exercises = [];
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
    final list = await getAllExercises(db);
    if (mounted) setState(() { _exercises = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Exercises', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/exercises/new').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exercises.isEmpty
              ? const Center(
                  child: Text('No exercises yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _exercises.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final ex = _exercises[i];
                    return GestureDetector(
                      onTap: () => context.push('/exercises/${ex.id}').then((_) => _load()),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex.name,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            if (ex.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(ex.description,
                                  style: const TextStyle(
                                      fontSize: 14, color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
