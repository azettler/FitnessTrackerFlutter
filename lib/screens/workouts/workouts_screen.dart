import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/workout_repository.dart';
import '../../theme/colors.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  Database? _db;
  List<WorkoutPlan> _plans = [];
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
    final plans = await getAllPlans(db);
    if (mounted) setState(() { _plans = plans; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workouts', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/workouts/plan/new').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(
                  child: Text('No workout plans yet.\nTap + to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  separatorBuilder: (context2, i) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final plan = _plans[i];
                    return GestureDetector(
                      onTap: () => context
                          .push('/workouts/plan/${plan.id}')
                          .then((_) => _load()),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.name,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            if (plan.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(plan.description,
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
