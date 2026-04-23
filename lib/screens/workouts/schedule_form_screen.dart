import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../repositories/schedule_repository.dart';
import '../../theme/colors.dart';

class ScheduleFormScreen extends StatefulWidget {
  final int planId;
  final int? scheduleId;
  const ScheduleFormScreen({super.key, required this.planId, this.scheduleId});

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  Database? _db;
  // Days of week selection (JS convention: 0=Sun…6=Sat)
  final Set<int> _selectedDays = {};
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _saving = false;

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _dayFull = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  bool get _isEditing => widget.scheduleId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    if (_isEditing) {
      final s = await getScheduleById(_db!, widget.scheduleId!);
      if (s != null && mounted) {
        final days = (s.daysOfWeek ?? '')
            .split(',')
            .where((d) => d.isNotEmpty)
            .map(int.parse)
            .toSet();
        setState(() {
          _selectedDays.addAll(days);
          _startDate = DateTime.parse('${s.startDate}T00:00:00');
          _endDate = s.endDate != null ? DateTime.parse('${s.endDate}T00:00:00') : null;
        });
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select at least one day')));
      return;
    }
    setState(() => _saving = true);
    final db = _db!;
    final fmt = DateFormat('yyyy-MM-dd');
    final daysOfWeek = _selectedDays.toList()..sort();
    final daysStr = daysOfWeek.join(',');
    final startStr = fmt.format(_startDate);
    final endStr = _endDate != null ? fmt.format(_endDate!) : null;

    try {
      if (_isEditing) {
        await updateSchedule(db, widget.scheduleId!,
            recurrenceType: 'specific_days',
            daysOfWeek: daysStr,
            startDate: startStr,
            endDate: endStr);
      } else {
        await createSchedule(db,
            workoutPlanId: widget.planId,
            recurrenceType: 'specific_days',
            daysOfWeek: daysStr,
            startDate: startStr,
            endDate: endStr);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Future pending instances will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await deleteSchedule(_db!, widget.scheduleId!);
    if (mounted) context.pop();
  }

  String _fmtDate(DateTime d) =>
      DateFormat('MMM d, yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Schedule' : 'Add Schedule',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('DAYS OF WEEK'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (jsDay) {
              final selected = _selectedDays.contains(jsDay);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedDays.remove(jsDay);
                  } else {
                    _selectedDays.add(jsDay);
                  }
                }),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? AppColors.accent : AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(_dayLabels[jsDay],
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }),
          ),
          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              (_selectedDays.toList()..sort()).map((d) => _dayFull[d]).join(', '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],

          const SizedBox(height: 24),
          _sectionLabel('START DATE'),
          const SizedBox(height: 8),
          _dateRow(_fmtDate(_startDate), () => _pickDate(true)),

          const SizedBox(height: 16),
          _sectionLabel('END DATE (OPTIONAL)'),
          const SizedBox(height: 8),
          _dateRow(
            _endDate != null ? _fmtDate(_endDate!) : 'No end date',
            () => _pickDate(false),
            trailing: _endDate != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => setState(() => _endDate = null),
                  )
                : null,
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
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),

          if (_isEditing) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Delete Schedule', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8));

  Widget _dateRow(String label, VoidCallback onTap, {Widget? trailing}) => GestureDetector(
        onTap: onTap,
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
                child: Text(label,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              ),
              ?trailing,
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      );
}
