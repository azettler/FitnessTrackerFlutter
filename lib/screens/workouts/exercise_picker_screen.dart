import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/exercise_repository.dart';
import '../../theme/colors.dart';

class ExercisePickerScreen extends StatefulWidget {
  final Map<String, dynamic> extra;
  const ExercisePickerScreen({super.key, required this.extra});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  Database? _db;
  List<Exercise> _all = [];
  List<Exercise> _filtered = [];
  Set<int> _selected = {};
  // exerciseId → {targetSets, targetReps} preserved from parent
  final Map<int, Map<String, int>> _setRepMap = {};
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final selectedIds = (widget.extra['selectedIds'] as List?)?.cast<int>() ?? [];
    _selected = selectedIds.toSet();
    _searchCtrl.addListener(_filter);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    final exercises = await getAllExercises(_db!);
    if (mounted) {
      setState(() {
        _all = exercises;
        _filtered = exercises;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((e) => e.name.toLowerCase().contains(q)).toList();
    });
  }

  void _toggle(Exercise ex) {
    setState(() {
      if (_selected.contains(ex.id)) {
        _selected.remove(ex.id);
      } else {
        _selected.add(ex.id);
      }
    });
  }

  void _done() {
    final result = _all
        .where((e) => _selected.contains(e.id))
        .map((e) => {
              'exerciseId': e.id,
              'exerciseName': e.name,
              'targetSets': _setRepMap[e.id]?['targetSets'] ?? 3,
              'targetReps': _setRepMap[e.id]?['targetReps'] ?? 10,
            })
        .toList();
    context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Exercises', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _done,
            child: const Text('Done',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 16),
              itemBuilder: (ctx, i) {
                final ex = _filtered[i];
                final isSelected = _selected.contains(ex.id);
                return ListTile(
                  title: Text(ex.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  subtitle: ex.description.isNotEmpty
                      ? Text(ex.description,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
                      : null,
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.accent)
                      : const Icon(Icons.radio_button_unchecked, color: AppColors.border),
                  onTap: () => _toggle(ex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
