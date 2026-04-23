import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/exempt_day_repository.dart';
import '../../repositories/instance_repository.dart';
import '../../services/day_status_calculator.dart';
import '../../services/schedule_generator.dart';
import '../../theme/colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Database? _db;
  DateTime _focusedDay = DateTime.now();
  Map<String, DayStatus> _statusMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    // Run schedule generation on first load
    await generateInstances(_db!);
    await _load();
  }

  Future<void> _load() async {
    final db = _db;
    if (db == null) return;

    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1)
        .subtract(const Duration(days: 6));
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
        .add(const Duration(days: 6));

    final startStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final endStr = DateFormat('yyyy-MM-dd').format(lastDay);

    final instances = await getInstancesForDateRange(db, startStr, endStr);
    final exemptDays = await getExemptDaysForRange(db, startStr, endStr);
    final exemptSet = exemptDays.map((e) => e.date).toSet();

    final byDate = <String, List<WorkoutInstance>>{};
    for (final inst in instances) {
      byDate.putIfAbsent(inst.scheduledDate, () => []).add(inst);
    }

    final statusMap = <String, DayStatus>{};
    DateTime cur = firstDay;
    while (!cur.isAfter(lastDay)) {
      final ds = DateFormat('yyyy-MM-dd').format(cur);
      statusMap[ds] = computeDayStatus(ds, byDate[ds] ?? [], exemptSet);
      cur = cur.add(const Duration(days: 1));
    }

    if (mounted) {
      setState(() {
        _statusMap = statusMap;
        _loading = false;
      });
    }
  }

  Color? _dayColor(String dateStr) {
    final status = _statusMap[dateStr];
    if (status == null || status == DayStatus.neutral || status == DayStatus.exempt) return null;
    return statusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 8),
                _buildCalendar(),
                const SizedBox(height: 12),
                _buildLegend(),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime(2030),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.accent),
          rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.accent),
          headerPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          weekendStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: true,
          outsideTextStyle: TextStyle(color: AppColors.textMuted),
          defaultTextStyle: TextStyle(color: AppColors.textPrimary),
          weekendTextStyle: TextStyle(color: AppColors.textPrimary),
          todayDecoration: BoxDecoration(shape: BoxShape.circle),
          todayTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          selectedDecoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, date, _) => _buildDay(date, isOutside: false),
          outsideBuilder: (context, date, _) => _buildDay(date, isOutside: true),
          todayBuilder: (context, date, _) => _buildDay(date, isToday: true),
        ),
        onDaySelected: (selected, focused) {
          final dateStr = DateFormat('yyyy-MM-dd').format(selected);
          context.push('/calendar/day/$dateStr').then((_) => _load());
        },
        onPageChanged: (day) {
          setState(() {
            _focusedDay = day;
            _loading = true;
          });
          _load();
        },
      ),
    );
  }

  Widget _buildDay(DateTime date, {bool isOutside = false, bool isToday = false}) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final color = _dayColor(dateStr);
    final textColor = color != null
        ? Colors.white
        : isOutside
            ? AppColors.textMuted
            : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: color != null
          ? BoxDecoration(color: color, shape: BoxShape.circle)
          : isToday
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 1.5),
                )
              : null,
      alignment: Alignment.center,
      child: Text(
        '${date.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: color != null || isToday ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    const items = [
      (AppColors.statusComplete, 'Complete'),
      (AppColors.statusPartial, 'Partial'),
      (AppColors.statusScheduled, 'Scheduled'),
      (AppColors.statusSkipped, 'Skipped'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: item.$1, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(item.$2,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
