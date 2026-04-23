import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/goal_repository.dart';
import '../../theme/colors.dart';

class GoalFormScreen extends StatefulWidget {
  final int? goalId;
  const GoalFormScreen({super.key, this.goalId});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  Database? _db;
  // Step 1: select exercise; Step 2: set weight + due date
  _Step _step = _Step.exercise;

  List<Exercise> _all = [];
  List<Exercise> _filtered = [];
  Exercise? _selected;
  final _searchCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    final exercises = await getAllExercises(_db!);
    if (mounted) {
      setState(() { _all = exercises; _filtered = exercises; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? _all : _all.where((e) => e.name.toLowerCase().contains(q)).toList();
    });
  }

  void _selectExercise(Exercise ex) {
    setState(() { _selected = ex; _step = _Step.details; });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final ex = _selected;
    if (ex == null) return;
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid target weight')));
      return;
    }
    setState(() => _saving = true);
    final db = _db!;
    try {
      final baseline = await getBestWeightForExercise(db, ex.id);
      final dueStr = _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null;
      await createGoal(db,
          exerciseId: ex.id,
          targetWeightLbs: weight,
          dueDate: dueStr,
          baselineWeightLbs: baseline);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_step == _Step.exercise ? 'New Goal' : 'Set Target',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: _step == _Step.details
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = _Step.exercise),
              )
            : null,
      ),
      body: _step == _Step.exercise ? _buildExercisePicker() : _buildDetails(),
    );
  }

  Widget _buildExercisePicker() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent)),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 16),
              itemBuilder: (ctx, i) {
                final ex = _filtered[i];
                return ListTile(
                  title: Text(ex.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  subtitle: ex.description.isNotEmpty
                      ? Text(ex.description,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
                      : null,
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () => _selectExercise(ex),
                );
              },
            ),
          ),
        ],
      );

  Widget _buildDetails() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(_selected?.name ?? ''),
          const SizedBox(height: 20),
          _label('TARGET WEIGHT (LBS)'),
          const SizedBox(height: 6),
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. 225',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 16),
          _label('DUE DATE (OPTIONAL)'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDueDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueDate != null
                          ? DateFormat('MMM d, yyyy').format(_dueDate!)
                          : 'No due date',
                      style: TextStyle(
                          fontSize: 15,
                          color: _dueDate != null ? AppColors.textPrimary : AppColors.textMuted),
                    ),
                  ),
                  if (_dueDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _dueDate = null),
                      child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
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
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8));

  Widget _infoCard(String name) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
      );
}

enum _Step { exercise, details }
