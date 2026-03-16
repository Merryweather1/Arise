import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

// ─── SCREEN ───────────────────────────────────────────────────────────────
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _period = 'Week'; // Week / Month / Year

  final _tasksDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final List<int> _tasksData = [];
  final List<double> _habitsData = [];
  final List<int> _focusData = [];
  final List<int> _pomodoroData = [];
  final Map<String, int> _categoryData = {};

  final _categoryColors = [
    AColors.primary, AColors.info, AColors.warning,
    const Color(0xFFBF7FF5), AColors.error, const Color(0xFFFF6B9D),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  int get _totalTasks => _tasksData.fold(0, (a, b) => a + b);
  int get _totalFocus => _focusData.fold(0, (a, b) => a + b);
  int get _totalPomodoro => _pomodoroData.fold(0, (a, b) => a + b);
  double get _avgHabits =>
      _habitsData.isEmpty ? 0 : _habitsData.fold(0.0, (a, b) => a + b) / _habitsData.length;
  int get _bestDay => _tasksData.isEmpty ? 0 : _tasksData.reduce(math.max);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AColors.bg,
      body: SafeArea(child: Column(children: [

        // ── Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Statistics', style: AText.displayMedium),
              Text('Your productivity insights', style: AText.bodyMedium),
            ])),
            // Period selector
            _PeriodSelector(
              current: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ATabBar(controller: _tabCtrl,
              tabs: const ['Overview', 'Tasks', 'Habits']),
        ),

        const SizedBox(height: 16),

        // ── Content
        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          _OverviewTab(
            totalTasks: _totalTasks,
            totalFocus: _totalFocus,
            totalPomodoro: _totalPomodoro,
            avgHabits: _avgHabits,
            bestDay: _bestDay,
            tasksData: _tasksData,
            tasksDays: _tasksDays,
            focusData: _focusData,
            categoryData: _categoryData,
            categoryColors: _categoryColors,
          ),
          _TasksTab(
            data: _tasksData,
            days: _tasksDays,
            categoryData: _categoryData,
            categoryColors: _categoryColors,
            total: _totalTasks,
            bestDay: _bestDay,
          ),
          _HabitsTab(
            data: _habitsData,
            days: _tasksDays,
            pomodoroData: _pomodoroData,
            avgRate: _avgHabits,
          ),
        ])),
      ])),
    );
  }
}

// ─── OVERVIEW TAB ─────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final int totalTasks, totalFocus, totalPomodoro, bestDay;
  final double avgHabits;
  final List<int> tasksData, focusData;
  final List<String> tasksDays;
  final Map<String, int> categoryData;
  final List<Color> categoryColors;

  const _OverviewTab({
    required this.totalTasks, required this.totalFocus,
    required this.totalPomodoro, required this.avgHabits,
    required this.bestDay, required this.tasksData,
    required this.tasksDays, required this.focusData,
    required this.categoryData, required this.categoryColors,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [

        // ── Hero stats grid
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _HeroStat(value: '$totalTasks', label: 'Tasks Done',
                icon: Icons.check_circle_rounded, color: AColors.primary,
                sub: 'This week'),
            _HeroStat(value: '${(totalFocus / 60).toStringAsFixed(1)}h', label: 'Focus Time',
                icon: Icons.timer_rounded, color: AColors.info,
                sub: '$totalFocus min total'),
            _HeroStat(value: '$totalPomodoro🍅', label: 'Pomodoros',
                icon: Icons.hourglass_bottom_rounded, color: AColors.warning,
                sub: '${totalPomodoro * 25} min'),
            _HeroStat(value: '${(avgHabits * 100).round()}%', label: 'Habit Rate',
                icon: Icons.loop_rounded, color: const Color(0xFFBF7FF5),
                sub: '7-day average'),
          ],
        ),

        const SizedBox(height: 20),

        // ── Tasks bar chart
        _ChartCard(
          title: 'Tasks Completed',
          subtitle: '$totalTasks total · Best day: $bestDay',
          child: _BarChart(
            data: tasksData.map((v) => v.toDouble()).toList(),
            labels: tasksDays,
            color: AColors.primary,
            maxVal: (bestDay * 1.2).ceil().toDouble(),
          ),
        ),

        const SizedBox(height: 16),

        // ── Focus time chart
        _ChartCard(
          title: 'Focus Time',
          subtitle: '${(totalFocus / 60).toStringAsFixed(1)}h total this week',
          child: _BarChart(
            data: focusData.map((v) => v.toDouble()).toList(),
            labels: tasksDays,
            color: AColors.info,
            maxVal: 150,
            unit: 'm',
          ),
        ),

        const SizedBox(height: 16),

        // ── Category donut
        _ChartCard(
          title: 'Tasks by Category',
          subtitle: '${categoryData.values.fold(0, (a,b)=>a+b)} tasks across ${categoryData.length} categories',
          child: _DonutChart(data: categoryData, colors: categoryColors),
        ),
      ],
    );
  }
}

// ─── TASKS TAB ────────────────────────────────────────────────────────────
class _TasksTab extends StatelessWidget {
  final List<int> data;
  final List<String> days;
  final Map<String, int> categoryData;
  final List<Color> categoryColors;
  final int total, bestDay;

  const _TasksTab({required this.data, required this.days,
    required this.categoryData, required this.categoryColors,
    required this.total, required this.bestDay});

  @override
  Widget build(BuildContext context) {
    final avg = data.fold(0, (a, b) => a + b) / data.length;
    final entries = categoryData.entries.toList();
    final catTotal = entries.fold(0, (a, e) => a + e.value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [

        // Stats row
        Row(children: [
          _MiniStatBox(label: 'Total', value: '$total', color: AColors.primary),
          const SizedBox(width: 10),
          _MiniStatBox(label: 'Daily Avg', value: avg.toStringAsFixed(1), color: AColors.info),
          const SizedBox(width: 10),
          _MiniStatBox(label: 'Best Day', value: '$bestDay', color: AColors.warning),
        ]),

        const SizedBox(height: 16),

        _ChartCard(
          title: 'Daily Completion',
          subtitle: 'Tasks completed per day',
          child: _BarChart(
            data: data.map((v) => v.toDouble()).toList(),
            labels: days, color: AColors.primary,
            maxVal: (bestDay * 1.2).ceil().toDouble(),
            showValues: true,
          ),
        ),

        const SizedBox(height: 16),

        // Category breakdown list
        _ChartCard(
          title: 'Category Breakdown',
          subtitle: '$total tasks total',
          child: Column(children: [
            // Segmented bar
            ClipRRect(
              borderRadius: ARadius.md,
              child: SizedBox(height: 12, child: Row(
                children: List.generate(entries.length, (i) {
                  final frac = entries[i].value / catTotal;
                  return Flexible(flex: (frac * 100).round(),
                      child: Container(color: categoryColors[i % categoryColors.length]));
                }),
              )),
            ),
            const SizedBox(height: 16),
            ...List.generate(entries.length, (i) {
              final frac = entries[i].value / catTotal;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                          color: categoryColors[i % categoryColors.length],
                          shape: BoxShape.circle)),
                  Expanded(child: Text(entries[i].key, style: AText.bodyMedium)),
                  Text('${entries[i].value}',
                      style: AText.bodyMedium.copyWith(color: AColors.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  SizedBox(width: 36, child: Text('${(frac * 100).round()}%', style: AText.bodySmall)),
                ]),
              );
            }),
          ]),
        ),
      ],
    );
  }
}

// ─── HABITS TAB ───────────────────────────────────────────────────────────
class _HabitsTab extends StatelessWidget {
  final List<double> data;
  final List<String> days;
  final List<int> pomodoroData;
  final double avgRate;

  const _HabitsTab({required this.data, required this.days,
    required this.pomodoroData, required this.avgRate});

  @override
  Widget build(BuildContext context) {
    final perfectDays = data.where((v) => v >= 1.0).length;
    final bestStreak = _calcStreak(data);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [

        Row(children: [
          _MiniStatBox(label: 'Avg Rate', value: '${(avgRate*100).round()}%', color: AColors.primary),
          const SizedBox(width: 10),
          _MiniStatBox(label: 'Perfect Days', value: '$perfectDays', color: const Color(0xFFBF7FF5)),
          const SizedBox(width: 10),
          _MiniStatBox(label: 'Best Streak', value: '$bestStreak🔥', color: AColors.warning),
        ]),

        const SizedBox(height: 16),

        _ChartCard(
          title: 'Habit Completion Rate',
          subtitle: '${(avgRate * 100).round()}% average this week',
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
          subtitle: '${pomodoroData.fold(0, (a,b)=>a+b)} sessions · ${pomodoroData.fold(0, (a,b)=>a+b) * 25} min',
          child: _BarChart(
            data: pomodoroData.map((v) => v.toDouble()).toList(),
            labels: days,
            color: AColors.warning,
            maxVal: 6,
            unit: '🍅',
            showValues: true,
          ),
        ),

        const SizedBox(height: 16),

        // Completion heatmap (last 4 weeks simulation)
        _ChartCard(
          title: '4-Week Heatmap',
          subtitle: 'Daily habit completion',
          child: _WeekHeatmap(),
        ),
      ],
    );
  }

  int _calcStreak(List<double> data) {
    int streak = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] >= 0.7) streak++; else break;
    }
    return streak;
  }
}

// ─── BAR CHART ────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final double maxVal;
  final String unit;
  final bool showValues;

  const _BarChart({required this.data, required this.labels,
    required this.color, required this.maxVal,
    this.unit = '', this.showValues = false});

  @override
  Widget build(BuildContext context) {
    final peak = data.reduce(math.max);
    return Column(children: [
      SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(data.length, (i) {
            final frac = maxVal > 0 ? (data[i] / maxVal).clamp(0.0, 1.0) : 0.0;
            final isToday = i == data.length - 1;
            final isPeak = data[i] == peak;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (showValues && data[i] > 0)
                  Text(
                      unit == '%' ? '${data[i].round()}%'
                          : unit == '🍅' ? '${data[i].round()}🍅'
                          : '${data[i].round()}$unit',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: isPeak ? color : AColors.textMuted)),
                const SizedBox(height: 3),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: frac),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 100 * val,
                    decoration: BoxDecoration(
                      color: isToday ? color
                          : isPeak ? color.withValues(alpha: 0.7)
                          : color.withValues(alpha: 0.35),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                ),
              ]),
            ));
          }),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: labels.map((l) => Expanded(child: Center(
          child: Text(l, style: AText.bodySmall)))).toList()),
    ]);
  }
}

// ─── DONUT CHART ──────────────────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;
  const _DonutChart({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (a, b) => a + b);
    final entries = data.entries.toList();

    return Row(children: [
      SizedBox(width: 130, height: 130,
          child: CustomPaint(painter: _DonutPainter(
            data: entries.map((e) => e.value.toDouble()).toList(),
            colors: colors,
          ))),
      const SizedBox(width: 16),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(entries.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: colors[i % colors.length], shape: BoxShape.circle)),
            Expanded(child: Text(entries[i].key, style: AText.bodySmall)),
            Text('${(entries[i].value / total * 100).round()}%',
                style: AText.bodySmall.copyWith(
                    color: colors[i % colors.length], fontWeight: FontWeight.w700)),
          ]),
        )),
      )),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  _DonutPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final sweep = 2 * math.pi * data[i] / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle, sweep, false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt,
      );
      // Gap
      startAngle += sweep + 0.04;
    }

    // Center hole label
    final tp = TextPainter(
      text: TextSpan(
          text: '${data.length}\n',
          style: const TextStyle(color: AColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          children: [TextSpan(text: 'categories',
              style: const TextStyle(color: AColors.textMuted, fontSize: 9, fontWeight: FontWeight.w500))]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override bool shouldRepaint(_DonutPainter old) => true;
}

// ─── WEEK HEATMAP ─────────────────────────────────────────────────────────
class _WeekHeatmap extends StatelessWidget {
  static final _rng = math.Random(99);
  static final _cells = List.generate(28, (_) => _rng.nextDouble());

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
          child: Center(child: Text(d, style: AText.bodySmall)))).toList()),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4, crossAxisSpacing: 4,
        children: _cells.map((v) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: v > 0.8 ? AColors.primary
                : v > 0.6 ? AColors.primary.withValues(alpha: 0.6)
                : v > 0.4 ? AColors.primary.withValues(alpha: 0.3)
                : AColors.bgElevated,
            borderRadius: ARadius.sm,
          ),
        )).toList(),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        const Text('Less  ', style: TextStyle(fontSize: 10, color: AColors.textMuted)),
        ...List.generate(4, (i) => Container(
            width: 12, height: 12, margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
                color: AColors.primary.withValues(alpha: [0.15, 0.3, 0.6, 1.0][i]),
                borderRadius: ARadius.sm))),
        const Text('  More', style: TextStyle(fontSize: 10, color: AColors.textMuted)),
      ]),
    ]);
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  final String current;
  final Function(String) onChanged;
  const _PeriodSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(color: AColors.bgCard, borderRadius: ARadius.md,
          border: Border.all(color: AColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min,
          children: ['Week', 'Month', 'Year'].map((p) {
            final sel = current == p;
            return GestureDetector(
              onTap: () { onChanged(p); HapticFeedback.selectionClick(); },
              child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: sel ? AColors.primary : Colors.transparent,
                      borderRadius: ARadius.md),
                  child: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AColors.textMuted))),
            );
          }).toList()),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AColors.bgCard, borderRadius: ARadius.lg,
          border: Border.all(color: AColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AText.titleSmall),
        const SizedBox(height: 2),
        Text(subtitle, style: AText.bodySmall),
        const SizedBox(height: 16),
        child,
      ]));
}

class _HeroStat extends StatelessWidget {
  final String value, label, sub;
  final IconData icon;
  final Color color;
  const _HeroStat({required this.value, required this.label,
    required this.icon, required this.color, required this.sub});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AColors.bgCard, borderRadius: ARadius.lg,
          border: Border.all(color: AColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const Spacer(),
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
        const Spacer(),
        Text(value, style: AText.titleLarge.copyWith(color: color)),
        Text(label, style: AText.bodySmall),
        Text(sub, style: AText.bodySmall.copyWith(color: AColors.textMuted, fontSize: 10)),
      ]));
}

class _MiniStatBox extends StatelessWidget {
  final String label, value; final Color color;
  const _MiniStatBox({required this.label, required this.value, required this.color});
  @override Widget build(BuildContext context) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AColors.bgCard, borderRadius: ARadius.md,
          border: Border.all(color: AColors.border)),
      child: Column(children: [
        Text(value, style: AText.titleSmall.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(label, style: AText.bodySmall, textAlign: TextAlign.center),
      ])));
}

class _ATabBar extends StatelessWidget {
  final TabController controller; final List<String> tabs;
  const _ATabBar({required this.controller, required this.tabs});
  @override Widget build(BuildContext context) => Container(
      height: 44,
      decoration: BoxDecoration(color: AColors.bgCard, borderRadius: ARadius.md,
          border: Border.all(color: AColors.border)),
      child: TabBar(controller: controller,
          indicator: BoxDecoration(gradient: AColors.gradientPrimary, borderRadius: ARadius.md),
          indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
          labelStyle: AText.labelLarge, labelColor: Colors.white,
          unselectedLabelColor: AColors.textMuted,
          tabs: tabs.map((t) => Tab(text: t)).toList()));
}