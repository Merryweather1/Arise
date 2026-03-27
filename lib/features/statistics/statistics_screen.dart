import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _period = 'Week';

  final _categoryColors = const [
    AColors.primary,
    AColors.info,
    AColors.warning,
    Color(0xFFBF7FF5),
    AColors.error,
    Color(0xFFFF6B9D),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).valueOrNull ?? <TaskModel>[];
    final habits = ref.watch(habitsProvider).valueOrNull ?? <HabitModel>[];
    final sessions = ref.watch(pomodoroSessionsProvider).valueOrNull ?? <PomodoroSession>[];

    final stats = _buildStats(
      period: _period,
      now: DateTime.now(),
      tasks: tasks,
      habits: habits,
      sessions: sessions,
    );

    final hasRealData = stats.totalTasks > 0 ||
        stats.totalFocus > 0 ||
        stats.totalPomodoro > 0 ||
        stats.avgHabits > 0 ||
        stats.categoryData.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Statistics', style: AText.displayMedium),
                        Text('Your productivity insights', style: AText.bodyMedium),
                      ],
                    ),
                  ),
                  _PeriodSelector(
                    current: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ATabBar(
                controller: _tabCtrl,
                tabs: const ['Overview', 'Tasks', 'Habits'],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: !hasRealData
                  ? _StatisticsEmptyState(period: _period)
                  : TabBarView(
                controller: _tabCtrl,
                children: [
                  _OverviewTab(
                    totalTasks: stats.totalTasks,
                    totalFocus: stats.totalFocus,
                    totalPomodoro: stats.totalPomodoro,
                    avgHabits: stats.avgHabits,
                    bestDay: stats.bestDay,
                    tasksData: stats.tasksData,
                    tasksDays: stats.labels,
                    focusData: stats.focusData,
                    categoryData: stats.categoryData,
                    categoryColors: _categoryColors,
                  ),
                  _TasksTab(
                    data: stats.tasksData,
                    days: stats.labels,
                    categoryData: stats.categoryData,
                    categoryColors: _categoryColors,
                    total: stats.totalTasks,
                    bestDay: stats.bestDay,
                  ),
                  _HabitsTab(
                    data: stats.habitsData,
                    days: stats.labels,
                    pomodoroData: stats.pomodoroData,
                    avgRate: stats.avgHabits,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComputedStats {
  final List<String> labels;
  final List<int> tasksData;
  final List<double> habitsData; // 0..1
  final List<int> focusData; // minutes
  final List<int> pomodoroData; // sessions
  final Map<String, int> categoryData;

  final int totalTasks;
  final int totalFocus;
  final int totalPomodoro;
  final double avgHabits;
  final int bestDay;

  const _ComputedStats({
    required this.labels,
    required this.tasksData,
    required this.habitsData,
    required this.focusData,
    required this.pomodoroData,
    required this.categoryData,
    required this.totalTasks,
    required this.totalFocus,
    required this.totalPomodoro,
    required this.avgHabits,
    required this.bestDay,
  });
}

_ComputedStats _buildStats({
  required String period,
  required DateTime now,
  required List<TaskModel> tasks,
  required List<HabitModel> habits,
  required List<PomodoroSession> sessions,
}) {
  switch (period) {
    case 'Year':
      return _buildYearStats(now, tasks, habits, sessions);
    case 'Month':
      return _buildMonthStats(now, tasks, habits, sessions);
    case 'Week':
    default:
      return _buildWeekStats(now, tasks, habits, sessions);
  }
}

_ComputedStats _buildWeekStats(
    DateTime now,
    List<TaskModel> tasks,
    List<HabitModel> habits,
    List<PomodoroSession> sessions,
    ) {
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));

  final labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final tasksData = List<int>.filled(7, 0);
  final focusData = List<int>.filled(7, 0);
  final pomodoroData = List<int>.filled(7, 0);

  final habitsDone = List<int>.filled(7, 0);
  final habitsTotal = List<int>.filled(7, 0);

  final completedTasks = tasks.where((t) => t.done).toList();

  for (final t in completedTasks) {
    final d = t.dueDate ?? t.createdAt;
    final idx = _dayDiff(monday, d);
    if (idx >= 0 && idx < 7) {
      tasksData[idx]++;
    }
  }

  for (final s in sessions) {
    final idx = _dayDiff(monday, s.date);
    if (idx >= 0 && idx < 7) {
      focusData[idx] += s.durationMinutes;
      pomodoroData[idx] += 1;
    }
  }

  for (int i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final weekday = day.weekday;
    final dateKey = _dateKey(day);

    final scheduled = habits.where((h) {
      if (h.archived) return false;
      // Habit must have already started by this day
      final habitStart = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      final dayOnly = DateTime(day.year, day.month, day.day);
      if (dayOnly.isBefore(habitStart)) return false;
      // Habit must not have expired by this day
      if (!h.isUnlimited && h.durationDays != null && h.durationDays! > 0) {
        final endInclusive = habitStart.add(Duration(days: h.durationDays! - 1));
        if (dayOnly.isAfter(endInclusive)) return false;
      }
      if (h.scheduleDays.isEmpty) return true;
      return h.scheduleDays.contains(weekday);
    }).toList();

    habitsTotal[i] = scheduled.length;
    habitsDone[i] = scheduled.where((h) => h.completionDates.contains(dateKey)).length;
  }

  final habitsData = List<double>.generate(7, (i) {
    final total = habitsTotal[i];
    if (total == 0) return 0;
    return habitsDone[i] / total;
  });

  final categoryData = _buildCategoryData(
    completedTasks,
    monday,
    monday.add(const Duration(days: 6)),
  );

  return _finalize(
    labels: labels,
    tasksData: tasksData,
    habitsData: habitsData,
    focusData: focusData,
    pomodoroData: pomodoroData,
    categoryData: categoryData,
  );
}

_ComputedStats _buildMonthStats(
    DateTime now,
    List<TaskModel> tasks,
    List<HabitModel> habits,
    List<PomodoroSession> sessions,
    ) {
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  final daysInMonth = end.day;

  final weekCount = ((daysInMonth + start.weekday - 1) / 7).ceil();
  final labels = List.generate(weekCount, (i) => 'W${i + 1}');

  final tasksData = List<int>.filled(weekCount, 0);
  final focusData = List<int>.filled(weekCount, 0);
  final pomodoroData = List<int>.filled(weekCount, 0);

  final habitsDone = List<int>.filled(weekCount, 0);
  final habitsTotal = List<int>.filled(weekCount, 0);

  final completedTasks = tasks.where((t) => t.done).toList();

  for (final t in completedTasks) {
    final d = t.dueDate ?? t.createdAt;
    if (!_isInRange(d, start, end)) continue;
    final idx = ((d.day - 1) / 7).floor();
    if (idx >= 0 && idx < weekCount) {
      tasksData[idx]++;
    }
  }

  for (final s in sessions) {
    if (!_isInRange(s.date, start, end)) continue;
    final idx = ((s.date.day - 1) / 7).floor();
    if (idx >= 0 && idx < weekCount) {
      focusData[idx] += s.durationMinutes;
      pomodoroData[idx] += 1;
    }
  }

  for (int day = 1; day <= daysInMonth; day++) {
    final date = DateTime(now.year, now.month, day);
    final idx = ((day - 1) / 7).floor();
    if (idx < 0 || idx >= weekCount) continue;

    final weekday = date.weekday;
    final dateKey = _dateKey(date);

    final scheduled = habits.where((h) {
      if (h.archived) return false;
      final habitStart = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      final dayOnly = DateTime(date.year, date.month, date.day);
      if (dayOnly.isBefore(habitStart)) return false;
      if (!h.isUnlimited && h.durationDays != null && h.durationDays! > 0) {
        final endInclusive = habitStart.add(Duration(days: h.durationDays! - 1));
        if (dayOnly.isAfter(endInclusive)) return false;
      }
      if (h.scheduleDays.isEmpty) return true;
      return h.scheduleDays.contains(weekday);
    }).toList();

    habitsTotal[idx] += scheduled.length;
    habitsDone[idx] += scheduled.where((h) => h.completionDates.contains(dateKey)).length;
  }

  final habitsData = List<double>.generate(weekCount, (i) {
    final total = habitsTotal[i];
    if (total == 0) return 0;
    return habitsDone[i] / total;
  });

  final categoryData = _buildCategoryData(completedTasks, start, end);

  return _finalize(
    labels: labels,
    tasksData: tasksData,
    habitsData: habitsData,
    focusData: focusData,
    pomodoroData: pomodoroData,
    categoryData: categoryData,
  );
}

_ComputedStats _buildYearStats(
    DateTime now,
    List<TaskModel> tasks,
    List<HabitModel> habits,
    List<PomodoroSession> sessions,
    ) {
  final start = DateTime(now.year, 1, 1);
  final end = DateTime(now.year, 12, 31);

  const labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  final tasksData = List<int>.filled(12, 0);
  final focusData = List<int>.filled(12, 0);
  final pomodoroData = List<int>.filled(12, 0);

  final habitsDone = List<int>.filled(12, 0);
  final habitsTotal = List<int>.filled(12, 0);

  final completedTasks = tasks.where((t) => t.done).toList();

  for (final t in completedTasks) {
    final d = t.dueDate ?? t.createdAt;
    if (!_isInRange(d, start, end)) continue;
    tasksData[d.month - 1]++;
  }

  for (final s in sessions) {
    if (!_isInRange(s.date, start, end)) continue;
    final idx = s.date.month - 1;
    focusData[idx] += s.durationMinutes;
    pomodoroData[idx] += 1;
  }

  var cursor = start;
  while (!cursor.isAfter(end)) {
    final idx = cursor.month - 1;
    final weekday = cursor.weekday;
    final dateKey = _dateKey(cursor);

    final scheduled = habits.where((h) {
      if (h.archived) return false;
      final habitStart = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      final dayOnly = DateTime(cursor.year, cursor.month, cursor.day);
      if (dayOnly.isBefore(habitStart)) return false;
      if (!h.isUnlimited && h.durationDays != null && h.durationDays! > 0) {
        final endInclusive = habitStart.add(Duration(days: h.durationDays! - 1));
        if (dayOnly.isAfter(endInclusive)) return false;
      }
      if (h.scheduleDays.isEmpty) return true;
      return h.scheduleDays.contains(weekday);
    }).toList();

    habitsTotal[idx] += scheduled.length;
    habitsDone[idx] +=
        scheduled.where((h) => h.completionDates.contains(dateKey)).length;

    cursor = cursor.add(const Duration(days: 1));
  }

  final habitsData = List<double>.generate(12, (i) {
    final total = habitsTotal[i];
    if (total == 0) return 0;
    return habitsDone[i] / total;
  });

  final categoryData = _buildCategoryData(completedTasks, start, end);

  return _finalize(
    labels: labels,
    tasksData: tasksData,
    habitsData: habitsData,
    focusData: focusData,
    pomodoroData: pomodoroData,
    categoryData: categoryData,
  );
}

_ComputedStats _finalize({
  required List<String> labels,
  required List<int> tasksData,
  required List<double> habitsData,
  required List<int> focusData,
  required List<int> pomodoroData,
  required Map<String, int> categoryData,
}) {
  final totalTasks = tasksData.fold(0, (a, b) => a + b);
  final totalFocus = focusData.fold(0, (a, b) => a + b);
  final totalPomodoro = pomodoroData.fold(0, (a, b) => a + b);

  final nonZeroHabits = habitsData.where((v) => v > 0).toList();
  final avgHabits = nonZeroHabits.isEmpty
      ? 0.0
      : nonZeroHabits.fold(0.0, (a, b) => a + b) / nonZeroHabits.length;

  final bestDay = tasksData.isEmpty ? 0 : tasksData.reduce(math.max);

  return _ComputedStats(
    labels: labels,
    tasksData: tasksData,
    habitsData: habitsData,
    focusData: focusData,
    pomodoroData: pomodoroData,
    categoryData: categoryData,
    totalTasks: totalTasks,
    totalFocus: totalFocus,
    totalPomodoro: totalPomodoro,
    avgHabits: avgHabits,
    bestDay: bestDay,
  );
}

Map<String, int> _buildCategoryData(
    List<TaskModel> completedTasks,
    DateTime start,
    DateTime end,
    ) {
  final map = <String, int>{};

  for (final t in completedTasks) {
    final d = t.dueDate ?? t.createdAt;
    if (!_isInRange(d, start, end)) continue;

    final c = t.category.trim().isEmpty ? 'Other' : t.category.trim();
    map[c] = (map[c] ?? 0) + 1;
  }

  return map;
}

bool _isInRange(DateTime value, DateTime start, DateTime end) {
  final d = DateTime(value.year, value.month, value.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !d.isBefore(s) && !d.isAfter(e);
}

int _dayDiff(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _StatisticsEmptyState extends StatelessWidget {
  final String period;
  const _StatisticsEmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insights_outlined, size: 56, color: AColors.textMuted),
            const SizedBox(height: 12),
            const Text('No statistics yet', style: AText.titleMedium),
            const SizedBox(height: 6),
            Text(
              'No real data found for $period.\nComplete tasks, habits, or focus sessions to see insights.',
              textAlign: TextAlign.center,
              style: AText.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- OVERVIEW TAB -----------------

class _OverviewTab extends StatelessWidget {
  final int totalTasks, totalFocus, totalPomodoro, bestDay;
  final double avgHabits;
  final List<int> tasksData, focusData;
  final List<String> tasksDays;
  final Map<String, int> categoryData;
  final List<Color> categoryColors;

  const _OverviewTab({
    required this.totalTasks,
    required this.totalFocus,
    required this.totalPomodoro,
    required this.avgHabits,
    required this.bestDay,
    required this.tasksData,
    required this.tasksDays,
    required this.focusData,
    required this.categoryData,
    required this.categoryColors,
  });

  @override
  Widget build(BuildContext context) {
    final safeMaxTasks = bestDay <= 0 ? 1.0 : (bestDay * 1.2).ceilToDouble();
    final safeMaxFocus =
    (focusData.isEmpty ? 0 : focusData.reduce(math.max)).toDouble() <= 0
        ? 1.0
        : (focusData.reduce(math.max) * 1.2).ceilToDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _HeroStat(
              value: '$totalTasks',
              label: 'Tasks Done',
              icon: Icons.check_circle_rounded,
              color: AColors.primary,
              sub: 'Selected period',
            ),
            _HeroStat(
              value: '${(totalFocus / 60).toStringAsFixed(1)}h',
              label: 'Focus Time',
              icon: Icons.timer_rounded,
              color: AColors.info,
              sub: '$totalFocus min total',
            ),
            _HeroStat(
              value: '$totalPomodoro',
              label: 'Pomodoros',
              icon: Icons.hourglass_bottom_rounded,
              color: AColors.warning,
              sub: '${totalPomodoro * 25} min',
            ),
            _HeroStat(
              value: '${(avgHabits * 100).round()}%',
              label: 'Habit Rate',
              icon: Icons.loop_rounded,
              color: const Color(0xFFBF7FF5),
              sub: 'Average completion',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ChartCard(
          title: 'Tasks Completed',
          subtitle: '$totalTasks total • Best bucket: $bestDay',
          child: _BarChart(
            data: tasksData.map((v) => v.toDouble()).toList(),
            labels: tasksDays,
            color: AColors.primary,
            maxVal: safeMaxTasks,
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Focus Time',
          subtitle: '${(totalFocus / 60).toStringAsFixed(1)}h total',
          child: _BarChart(
            data: focusData.map((v) => v.toDouble()).toList(),
            labels: tasksDays,
            color: AColors.info,
            maxVal: safeMaxFocus,
            unit: 'm',
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Tasks by Category',
          subtitle:
          '${categoryData.values.fold(0, (a, b) => a + b)} tasks across ${categoryData.length} categories',
          child: _DonutChart(data: categoryData, colors: categoryColors),
        ),
      ],
    );
  }
}

// ----------------- TASKS TAB -----------------

class _TasksTab extends StatelessWidget {
  final List<int> data;
  final List<String> days;
  final Map<String, int> categoryData;
  final List<Color> categoryColors;
  final int total, bestDay;

  const _TasksTab({
    required this.data,
    required this.days,
    required this.categoryData,
    required this.categoryColors,
    required this.total,
    required this.bestDay,
  });

  @override
  Widget build(BuildContext context) {
    final avg = data.isEmpty ? 0.0 : data.fold(0, (a, b) => a + b) / data.length;
    final entries = categoryData.entries.toList();
    final catTotal = entries.fold(0, (a, e) => a + e.value);
    final safeMax = bestDay <= 0 ? 1.0 : (bestDay * 1.2).ceilToDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            _MiniStatBox(label: 'Total', value: '$total', color: AColors.primary),
            const SizedBox(width: 10),
            _MiniStatBox(
              label: 'Avg',
              value: avg.toStringAsFixed(1),
              color: AColors.info,
            ),
            const SizedBox(width: 10),
            _MiniStatBox(
              label: 'Best',
              value: '$bestDay',
              color: AColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Daily / Bucket Completion',
          subtitle: 'Tasks completed by selected period buckets',
          child: _BarChart(
            data: data.map((v) => v.toDouble()).toList(),
            labels: days,
            color: AColors.primary,
            maxVal: safeMax,
            showValues: true,
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Category Breakdown',
          subtitle: '$total tasks total',
          child: entries.isEmpty
              ? const Text('No category data', style: AText.bodyMedium)
              : Column(
            children: [
              ClipRRect(
                borderRadius: ARadius.md,
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: List.generate(entries.length, (i) {
                      final frac = catTotal == 0
                          ? 0.0
                          : entries[i].value / catTotal;
                      final flex = math.max(1, (frac * 100).round());
                      return Flexible(
                        flex: flex,
                        child: Container(
                          color: categoryColors[i % categoryColors.length],
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(entries.length, (i) {
                final frac =
                catTotal == 0 ? 0.0 : entries[i].value / catTotal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: categoryColors[i % categoryColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(entries[i].key, style: AText.bodyMedium),
                      ),
                      Text(
                        '${entries[i].value}',
                        style: AText.bodyMedium.copyWith(
                          color: AColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(frac * 100).round()}%',
                          style: AText.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------- HABITS TAB -----------------

class _HabitsTab extends StatelessWidget {
  final List<double> data; // 0..1
  final List<String> days;
  final List<int> pomodoroData;
  final double avgRate;

  const _HabitsTab({
    required this.data,
    required this.days,
    required this.pomodoroData,
    required this.avgRate,
  });

  @override
  Widget build(BuildContext context) {
    final perfectBuckets = data.where((v) => v >= 1.0).length;
    final bestStreak = _calcStreak(data);
    final totalPomodoro = pomodoroData.fold(0, (a, b) => a + b);
    final pomodoroMax =
    (pomodoroData.isEmpty ? 0 : pomodoroData.reduce(math.max)).toDouble() <= 0
        ? 1.0
        : (pomodoroData.reduce(math.max) * 1.2).ceilToDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            _MiniStatBox(
              label: 'Avg Rate',
              value: '${(avgRate * 100).round()}%',
              color: AColors.primary,
            ),
            const SizedBox(width: 10),
            _MiniStatBox(
              label: 'Perfect',
              value: '$perfectBuckets',
              color: const Color(0xFFBF7FF5),
            ),
            const SizedBox(width: 10),
            _MiniStatBox(
              label: 'Streak',
              value: '$bestStreak',
              color: AColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Habit Completion Rate',
          subtitle: '${(avgRate * 100).round()}% average',
          child: _BarChart(
            data: data.map((v) => v * 100).toList(),
            labels: days,
            color: const Color(0xFFBF7FF5),
            maxVal: 100,
            unit: '%',
            showValues: true,
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Pomodoro Sessions',
          subtitle: '$totalPomodoro sessions • ${totalPomodoro * 25} min',
          child: _BarChart(
            data: pomodoroData.map((v) => v.toDouble()).toList(),
            labels: days,
            color: AColors.warning,
            maxVal: pomodoroMax,
            unit: 'x',
            showValues: true,
          ),
        ),
      ],
    );
  }

  int _calcStreak(List<double> values) {
    int streak = 0;
    for (int i = values.length - 1; i >= 0; i--) {
      if (values[i] >= 0.7) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

// ----------------- WIDGETS -----------------

class _BarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final double maxVal;
  final String unit;
  final bool showValues;

  const _BarChart({
    required this.data,
    required this.labels,
    required this.color,
    required this.maxVal,
    this.unit = '',
    this.showValues = false,
  });

  @override
  Widget build(BuildContext context) {
    final peak = data.isEmpty ? 0.0 : data.reduce(math.max);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(data.length, (i) {
              final frac = (data[i] / safeMax).clamp(0.0, 1.0);
              final isLast = i == data.length - 1;
              final isPeak = peak > 0 && data[i] == peak;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showValues && data[i] > 0)
                        Text(
                          unit == '%'
                              ? '${data[i].round()}%'
                              : '${data[i].round()}$unit',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isPeak ? color : AColors.textMuted,
                          ),
                        ),
                      const SizedBox(height: 3),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: frac),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (_, val, __) => Container(
                          height: 100 * val,
                          decoration: BoxDecoration(
                            color: isLast
                                ? color
                                : isPeak
                                ? color.withValues(alpha: 0.7)
                                : color.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: labels
              .map((l) => Expanded(
            child: Center(child: Text(l, style: AText.bodySmall)),
          ))
              .toList(),
        ),
      ],
    );
  }
}

class _DonutChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;
  const _DonutChart({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = data.values.fold(0, (a, b) => a + b);

    if (entries.isEmpty || total == 0) {
      return const Text('No category data', style: AText.bodyMedium);
    }

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutExpo,
            builder: (_, val, __) => CustomPaint(
              painter: _DonutPainter(
                data: entries.map((e) => e.value.toDouble()).toList(),
                colors: colors,
                progress: val,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(entries.length, (i) {
              final pct = ((entries[i].value / total) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Text(entries[i].key, style: AText.bodySmall)),
                    Text(
                      '$pct%',
                      style: AText.bodySmall.copyWith(
                        color: colors[i % colors.length],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  final double progress; // 0.0 to 1.0

  _DonutPainter({
    required this.data,
    required this.colors,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double start = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final sweep = 2 * math.pi * data[i] / total * progress; // Animate draw
      if (sweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep + 0.04;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: '${data.length}\n',
        style: const TextStyle(
          color: AColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        children: const [
          TextSpan(
            text: 'categories',
            style: TextStyle(
              color: AColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PeriodSelector extends StatelessWidget {
  final String current;
  final Function(String) onChanged;
  const _PeriodSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.md,
        border: Border.all(color: AColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Week', 'Month', 'Year'].map((p) {
          final sel = current == p;
          return GestureDetector(
            onTap: () {
              onChanged(p);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? AColors.primary : Colors.transparent,
                borderRadius: ARadius.md,
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : AColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuint,
      builder: (context, value, childWidget) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AColors.bgCard,
                borderRadius: ARadius.lg,
                border: Border.all(
                  color: AColors.primary.withValues(alpha: 0.2), // Subtle accent border
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AText.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AText.bodySmall),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label, sub;
  final IconData icon;
  final Color color;

  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AColors.bgCard,
        gradient: LinearGradient(
          colors: [
            AColors.bgCard,
            color.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: ARadius.lg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const Spacer(),
          Text(value, style: AText.titleLarge.copyWith(color: color)),
          Text(label, style: AText.bodySmall),
          Text(
            sub,
            style: AText.bodySmall.copyWith(
              color: AColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label, value;
  final Color color;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AColors.bgCard,
          borderRadius: ARadius.md,
          border: Border.all(color: AColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: AText.titleSmall.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label, style: AText.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ATabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _ATabBar({
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.md,
        border: Border.all(color: AColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: AColors.gradientPrimary,
          borderRadius: ARadius.md,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: AText.labelLarge,
        labelColor: Colors.white,
        unselectedLabelColor: AColors.textMuted,
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}