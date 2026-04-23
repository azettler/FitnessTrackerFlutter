import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/exempt_day_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/instance_repository.dart';
import '../../services/day_status_calculator.dart';
import '../../theme/colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  Database? _db;
  late TabController _tabs;
  bool _loading = true;

  // Month tab
  DateTime _monthFocus = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<String, DayStatus> _monthStatus = {};

  // Year tab
  bool _ytdMode = true;
  Map<String, DayStatus> _yearStatus = {};
  int _yearCompleted = 0, _yearScheduled = 0, _exemptCount = 0;

  // Exercise tab
  bool _chartMode30 = true;
  List<Exercise> _exercises = [];
  Exercise? _selectedExercise;
  List<FlSpot> _chartSpots = [];
  String _chartFilter = '';
  double _chartMin = 0, _chartMax = 200;

  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() { if (!_tabs.indexIsChanging) _loadAll(); });
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    await _loadAll();
  }

  Future<void> _loadAll() async {
    final db = _db;
    if (db == null) return;
    setState(() => _loading = true);

    await Future.wait([_loadMonth(db), _loadYear(db), _loadExercises(db)]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMonth(Database db) async {
    final first = _monthFocus;
    final last = DateTime(first.year, first.month + 1, 0);
    final s = _fmt.format(first), e = _fmt.format(last);
    final instances = await getInstancesForDateRange(db, s, e);
    final exempt = await getExemptDaysForRange(db, s, e);
    final exemptSet = exempt.map((x) => x.date).toSet();
    final byDate = <String, List<WorkoutInstance>>{};
    for (final i in instances) { byDate.putIfAbsent(i.scheduledDate, () => []).add(i); }
    final statusMap = <String, DayStatus>{};
    DateTime cur = first;
    while (!cur.isAfter(last)) {
      final ds = _fmt.format(cur);
      statusMap[ds] = computeDayStatus(ds, byDate[ds] ?? [], exemptSet);
      cur = cur.add(const Duration(days: 1));
    }
    if (mounted) setState(() => _monthStatus = statusMap);
  }

  Future<void> _loadYear(Database db) async {
    final now = DateTime.now();
    final start = _ytdMode ? DateTime(now.year, 1, 1) : now.subtract(const Duration(days: 365));
    final s = _fmt.format(start), e = _fmt.format(now);
    final instances = await getInstancesForDateRange(db, s, e);
    final exempt = await getExemptDaysForRange(db, s, e);
    final exemptSet = exempt.map((x) => x.date).toSet();
    final byDate = <String, List<WorkoutInstance>>{};
    for (final i in instances) { byDate.putIfAbsent(i.scheduledDate, () => []).add(i); }
    int completed = 0, scheduled = 0;
    final statusMap = <String, DayStatus>{};
    DateTime cur = start;
    while (!cur.isAfter(now)) {
      final ds = _fmt.format(cur);
      final status = computeDayStatus(ds, byDate[ds] ?? [], exemptSet);
      statusMap[ds] = status;
      if (status == DayStatus.complete || status == DayStatus.partial) completed++;
      if (status != DayStatus.neutral && status != DayStatus.exempt) scheduled++;
      cur = cur.add(const Duration(days: 1));
    }
    if (mounted) {
      setState(() {
        _yearStatus = statusMap;
        _yearCompleted = completed;
        _yearScheduled = scheduled;
        _exemptCount = exemptSet.length;
      });
    }
  }

  Future<void> _loadExercises(Database db) async {
    final exercises = await getAllExercises(db);
    if (mounted) {
      setState(() { _exercises = exercises; });
      if (_selectedExercise == null && exercises.isNotEmpty) {
        _selectedExercise = exercises.first;
        await _loadChart(db);
      } else if (_selectedExercise != null) {
        await _loadChart(db);
      }
    }
  }

  Future<void> _loadChart(Database db) async {
    final ex = _selectedExercise;
    if (ex == null) return;
    final now = DateTime.now();
    final start = _chartMode30
        ? now.subtract(const Duration(days: 30))
        : now.subtract(const Duration(days: 365));
    final s = _fmt.format(start), e = _fmt.format(now);

    final rows = await db.rawQuery(
      '''SELECT wi.scheduled_date, MAX(wis.weight_lbs) as max_weight
         FROM workout_instance_sets wis
         JOIN workout_instance_exercises wie ON wie.id = wis.workout_instance_exercise_id
         JOIN workout_instances wi ON wi.id = wie.workout_instance_id
         WHERE wie.exercise_id = ? AND wis.completed = 1 AND wis.weight_lbs IS NOT NULL
           AND wi.scheduled_date BETWEEN ? AND ?
         GROUP BY wi.scheduled_date
         ORDER BY wi.scheduled_date ASC''',
      [ex.id, s, e],
    );

    final spots = <FlSpot>[];
    double minW = double.infinity, maxW = 0;
    for (int i = 0; i < rows.length; i++) {
      final w = (rows[i]['max_weight'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), w));
      if (w < minW) minW = w;
      if (w > maxW) maxW = w;
    }

    if (mounted) {
      setState(() {
        _chartSpots = spots;
        _chartMin = spots.isEmpty ? 0 : (minW * 0.9).floorToDouble();
        _chartMax = spots.isEmpty ? 100 : (maxW * 1.1).ceilToDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textSecondary),
            onPressed: () => context.push('/reports/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [Tab(text: 'Month'), Tab(text: 'Year'), Tab(text: 'Exercise')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_buildMonth(), _buildYear(), _buildExercise()],
            ),
    );
  }

  // ─── Month tab ──────────────────────────────────────────────────────────────

  Widget _buildMonth() {
    final monthName = DateFormat('MMMM yyyy').format(_monthFocus);
    final scheduled = _monthStatus.values
        .where((s) => s != DayStatus.neutral && s != DayStatus.exempt)
        .length;
    final completed = _monthStatus.values
        .where((s) => s == DayStatus.complete || s == DayStatus.partial)
        .length;
    final pct = scheduled > 0 ? (completed * 100 ~/ scheduled) : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.accent),
                  onPressed: () {
                    setState(() => _monthFocus =
                        DateTime(_monthFocus.year, _monthFocus.month - 1, 1));
                    _loadMonth(_db!);
                  },
                ),
                Text(monthName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.accent),
                  onPressed: () {
                    setState(() => _monthFocus =
                        DateTime(_monthFocus.year, _monthFocus.month + 1, 1));
                    _loadMonth(_db!);
                  },
                ),
              ],
            ),
            Text('$completed of $scheduled scheduled workouts completed ($pct%)',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        )),
        const SizedBox(height: 16),
        _buildMonthHeatmap(),
      ],
    );
  }

  Widget _buildMonthHeatmap() {
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final first = _monthFocus;
    final last = DateTime(first.year, first.month + 1, 0);
    // firstDayOfWeek offset (0=Sun)
    final startOffset = first.weekday % 7;
    final totalCells = startOffset + last.day;
    final rows = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: dayLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          ...List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final day = cellIndex - startOffset + 1;
                if (day < 1 || day > last.day) {
                  return const Expanded(child: SizedBox(height: 40));
                }
                final ds = _fmt.format(DateTime(first.year, first.month, day));
                final status = _monthStatus[ds] ?? DayStatus.neutral;
                final color = status == DayStatus.neutral || status == DayStatus.exempt
                    ? null
                    : statusColor(status);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color ?? AppColors.statusNeutral,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: color != null ? Colors.white : AppColors.textSecondary,
                            fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  // ─── Year tab ───────────────────────────────────────────────────────────────

  Widget _buildYear() {
    final now = DateTime.now();
    final title = _ytdMode ? '${now.year} Year to Date' : 'Last 365 Days';
    final pct = _yearScheduled > 0
        ? (_yearCompleted * 100 ~/ _yearScheduled)
        : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('$_yearCompleted of $_yearScheduled workouts completed ($pct%) · $_exemptCount exempt days',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        )),
        const SizedBox(height: 12),
        _segmentedControl(
          options: ['Year to Date', 'Last 365 Days'],
          selectedIndex: _ytdMode ? 0 : 1,
          onSelect: (i) {
            setState(() => _ytdMode = i == 0);
            _loadYear(_db!);
          },
        ),
        const SizedBox(height: 16),
        _buildYearHeatmap(),
      ],
    );
  }

  Widget _buildYearHeatmap() {
    final now = DateTime.now();
    final start = _ytdMode
        ? DateTime(now.year, 1, 1)
        : now.subtract(const Duration(days: 365));

    // Build columns: each column = one week (7 days), starting Sunday
    // Align start to the Sunday of its week
    final startOffset = start.weekday % 7; // days since Sunday
    final alignedStart = start.subtract(Duration(days: startOffset));
    final totalDays = now.difference(alignedStart).inDays + 1;
    final totalCols = (totalDays / 7).ceil();

    // Collect month labels
    final monthLabels = <int, String>{};
    for (int c = 0; c < totalCols; c++) {
      final d = alignedStart.add(Duration(days: c * 7));
      if (c == 0 || d.day <= 7) {
        monthLabels[c] = DateFormat('MMM').format(d);
      }
    }

    const rowLabels = ['', 'M', '', 'W', '', 'F', ''];
    const cellSize = 11.0;
    const cellGap = 2.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month labels
            SizedBox(
              height: 16,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  ...List.generate(totalCols, (c) {
                    return SizedBox(
                      width: cellSize + cellGap,
                      child: monthLabels.containsKey(c)
                          ? Text(monthLabels[c]!,
                              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))
                          : null,
                    );
                  }),
                ],
              ),
            ),
            // Grid rows
            ...List.generate(7, (row) {
              return Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(rowLabels[row],
                        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                  ),
                  ...List.generate(totalCols, (col) {
                    final d = alignedStart.add(Duration(days: col * 7 + row));
                    if (d.isAfter(now)) {
                      return SizedBox(width: cellSize + cellGap, height: cellSize + cellGap);
                    }
                    final ds = _fmt.format(d);
                    final status = _yearStatus[ds] ?? DayStatus.neutral;
                    final color = status == DayStatus.neutral || status == DayStatus.exempt
                        ? AppColors.statusNeutral
                        : statusColor(status);
                    return Container(
                      width: cellSize,
                      height: cellSize,
                      margin: const EdgeInsets.all(cellGap / 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Exercise tab ────────────────────────────────────────────────────────────

  Widget _buildExercise() {
    final filtered = _chartFilter.isEmpty
        ? _exercises
        : _exercises.where((e) => e.name.toLowerCase().contains(_chartFilter.toLowerCase())).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight Progress',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 4),
            Text('Max weight logged per session for the selected exercise',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        )),
        const SizedBox(height: 12),
        _segmentedControl(
          options: ['Last 30 Days', 'Last 365 Days'],
          selectedIndex: _chartMode30 ? 0 : 1,
          onSelect: (i) {
            setState(() => _chartMode30 = i == 0);
            _loadChart(_db!);
          },
        ),
        const SizedBox(height: 12),

        // Filter box
        TextField(
          onChanged: (v) => setState(() => _chartFilter = v),
          decoration: InputDecoration(
            hintText: 'Filter exercises...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
        const SizedBox(height: 10),

        // Exercise chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filtered.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final ex = filtered[i];
              final isSelected = _selectedExercise?.id == ex.id;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedExercise = ex);
                  _loadChart(_db!);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                  ),
                  child: Text(ex.name,
                      style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13)),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Chart
        if (_chartSpots.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No data for this period.',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
                color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: LineChart(
              LineChartData(
                minY: _chartMin,
                maxY: _chartMax,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  border: const Border(
                    left: BorderSide(color: AppColors.border),
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots,
                    isCurved: true,
                    color: AppColors.accent,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────────────

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: child,
      );

  Widget _segmentedControl({
    required List<String> options,
    required int selectedIndex,
    required void Function(int) onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: options.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
