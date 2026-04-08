import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/notification_log_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'notification_center.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _hasAnimated = true);
    });
  }

  static const _taglines = [
    'Ready to Arise? 💪',
    'Make today count. ⚡',
    'One step at a time. 🎯',
    'Your future self is watching. 🔮',
    'Progress, not perfection. 📈',
    'Small steps, big wins. 🏆',
    'Build the life you want. 🌟',
    'Discipline is freedom. 🔓',
    'Show up. Every. Day. 🔥',
    'You got this. Seriously. 🙌',
    'Momentum starts here. 🚀',
    'Focus. Flow. Finish. ✨',
    'The grind is the gift. 🎁',
    'Earn your rest. 💤',
    'Today’s effort = tomorrow’s edge. 🔥',
    'Push past the plateau. 💪',
    'Winners start before they’re ready. 🚀',
    'Consistency over intensity. 📊',
    'No shortcuts, no regrets. 🤝',
    'Your habits shape your future. 🏗️',
    'Invest in yourself today. 💰',
    'Every rep counts. 💪',
    'Rise and dominate. 👑',
    'Keep the streak alive. 🔥',
    'Outwork yesterday. ⏰',
    'Dream big, execute bigger. 🛠️',
    'Be the hardest worker in the room. 🔑',
    'Lock in. Let’s go. 🎓',
    'Clarity + action = results. 🎯',
    'Take the shot. You’ll make it. 🏀',
    'ADAPT',
  ];

  String _tagline() {
    final d = DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day;
    return _taglines[seed % _taglines.length];
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isTaskToday(TaskModel task) {
    if (task.dueDate == null) return false;
    return _isSameDay(task.dueDate!, DateTime.now());
  }

  bool _isTaskUpcoming(TaskModel task) {
    if (task.dueDate == null) return false;
    final today = _dateOnly(DateTime.now());
    final due = _dateOnly(task.dueDate!);
    return due.isAfter(today);
  }

  bool _isHabitWithinDuration(HabitModel habit, DateTime day) {
    final target = _dateOnly(day);
    final start = _dateOnly(habit.createdAt);

    if (target.isBefore(start)) return false;
    if (habit.isUnlimited) return true;
    if (habit.durationDays == null || habit.durationDays! <= 0) return true;

    final endInclusive = start.add(Duration(days: habit.durationDays! - 1));
    return !target.isAfter(endInclusive);
  }

  bool _isHabitScheduledForToday(HabitModel habit) {
    if (habit.scheduleDays.isEmpty) return true;
    return habit.scheduleDays.contains(DateTime.now().weekday);
  }

  bool _isHabitVisibleToday(HabitModel habit) {
    return !habit.archived &&
        _isHabitWithinDuration(habit, DateTime.now()) &&
        _isHabitScheduledForToday(habit);
  }

  Color _taskPriorityColor(int p) {
    if (p >= 8) return AColors.priority1;
    if (p >= 5) return AColors.priority2;
    if (p >= 3) return AColors.priority3;
    return AColors.priority4;
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final habitsAsync = ref.watch(habitsProvider);

    // NEW: real data for focus/statistics/life-balance cards
    final pomodoroAsync = ref.watch(pomodoroSessionsProvider);
    final lifeBalanceAsync = ref.watch(lifeBalanceProvider);
    final latestBalance = ref.watch(latestBalanceProvider);

    final tasks = tasksAsync.valueOrNull ?? [];
    final habits = habitsAsync.valueOrNull ?? [];

    // NEW
    final pomodoroSessions = pomodoroAsync.valueOrNull ?? [];
    final lifeSnapshots = lifeBalanceAsync.valueOrNull ?? [];

    final todayTasks = tasks.where(_isTaskToday).toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return b.priority.compareTo(a.priority);
      });

    final upcomingTasks = tasks.where((t) => _isTaskUpcoming(t) && !t.done).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(2099))
          .compareTo(b.dueDate ?? DateTime(2099)));

    final todayHabits = habits.where(_isHabitVisibleToday).toList()
      ..sort((a, b) {
        if (a.isCompletedToday != b.isCompletedToday) {
          return a.isCompletedToday ? 1 : -1;
        }
        return b.streak.compareTo(a.streak);
      });

    final completedTasks = tasks.where((t) => t.done).length;
    final bestHabitStreak = habits.isEmpty
        ? 0
        : habits
        .map((h) => h.bestStreak)
        .reduce((a, b) => a > b ? a : b);

    // NEW: real focus for top stat card
    final today = DateTime.now();
    final todayFocusMinutes = pomodoroSessions
        .where((s) => _isSameDay(s.date, today))
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);

    // NEW: Life Balance summary
    final hasLifeData = lifeSnapshots.isNotEmpty && latestBalance != null;
    final latestLifeAverage = hasLifeData
        ? (latestBalance!.scores.isEmpty
        ? 0.0
        : latestBalance.scores.values.fold<double>(0.0, (a, b) => a + b) /
        latestBalance.scores.length)
        : 0.0;

    // NEW: Statistics summary
    final completedTasksTotal = tasks.where((t) => t.done).length;
    final totalFocusMinutes = pomodoroSessions.fold<int>(
      0,
          (sum, s) => sum + s.durationMinutes,
    );
    final totalPomodoroSessions = pomodoroSessions.length;

    final hasStatsData = completedTasksTotal > 0 ||
        totalFocusMinutes > 0 ||
        totalPomodoroSessions > 0;

    final dashboardTasks = todayTasks.isNotEmpty ? todayTasks : upcomingTasks;
    final dashboardTaskTitle =
    todayTasks.isNotEmpty ? "Today's Tasks" : 'Upcoming Tasks';

    final hasDashboardContent =
        dashboardTasks.isNotEmpty || todayHabits.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AColors.bg,
      body: Stack(
        children: [
          // Ethereal Top Glow
          Positioned(
            top: -150,
            left: -100,
            right: -100,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AColors.primary.withValues(alpha: 0.15),
                    blurRadius: 150,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(greeting: _greeting(), tagline: _tagline())),

              SliverToBoxAdapter(
                child: _AnimatedEntrance(
                  delay: 100,
                  play: _hasAnimated,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _XpCard(),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _AnimatedEntrance(
                  delay: 200,
                  play: _hasAnimated,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Row(
                      children: [
                        _StatCard(
                          icon: Icons.check_circle_rounded,
                          label: 'Tasks Done',
                          value: '$completedTasks',
                          color: AColors.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Best Streak',
                          value: '$bestHabitStreak',
                          color: AColors.warning,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.timer_rounded,
                          label: 'Focus Time',
                          value: '${todayFocusMinutes}m',
                          color: AColors.info,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _AnimatedEntrance(
                  delay: 300,
                  play: _hasAnimated,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FeatureCard(
                            onTap: () => context.push(ARoutes.lifeBalance),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A2F26), Color(0xFF0F2420)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            accentColor: AColors.primary,
                            icon: Icons.balance_rounded,
                            title: 'Life Balance',
                            subtitle: hasLifeData
                                ? 'Overall ${latestLifeAverage.toStringAsFixed(1)}/10'
                                : 'No snapshots yet',
                            badge: hasLifeData ? 'Live' : 'Empty',
                            badgeColor: hasLifeData ? AColors.primary : AColors.textMuted,
                            child: hasLifeData
                                ? _FeatureLiveStat(
                              text: '${lifeSnapshots.length} snapshot${lifeSnapshots.length == 1 ? '' : 's'}',
                            )
                                : const _FeaturePlaceholder(text: 'No data yet'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FeatureCard(
                            onTap: () => context.push(ARoutes.statistics),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A2030), Color(0xFF0F1520)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            accentColor: AColors.info,
                            icon: Icons.bar_chart_rounded,
                            title: 'Statistics',
                            subtitle: hasStatsData
                                ? '$completedTasksTotal tasks • ${totalFocusMinutes}m focus'
                                : 'No data yet',
                            badge: hasStatsData ? 'Live' : 'Empty',
                            badgeColor: hasStatsData ? AColors.info : AColors.textMuted,
                            child: hasStatsData
                                ? _FeatureLiveStat(
                              text: '$totalPomodoroSessions session${totalPomodoroSessions == 1 ? '' : 's'} logged',
                            )
                                : const _FeaturePlaceholder(text: 'No stats yet'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (hasDashboardContent) ...[
                if (dashboardTasks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: dashboardTaskTitle,
                      action: 'See all',
                      onAction: () => context.go(ARoutes.tasks),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (_, i) {
                          final task = dashboardTasks[i];
                          return _AnimatedEntrance(
                            delay: 300 + (i * 100),
                            play: _hasAnimated,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TaskDashboardCard(
                                task: task,
                                priorityColor: _taskPriorityColor(task.priority),
                                onTap: () => context.go(ARoutes.tasks),
                                onToggle: () async {
                                  final notifier = ref.read(taskActionsProvider.notifier);
                                  await notifier.setDone(task, !task.done);
                                  HapticFeedback.lightImpact();
                                },
                              ),
                            ),
                          );
                        },
                        childCount:
                        dashboardTasks.length > 4 ? 4 : dashboardTasks.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],

                if (todayHabits.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: "Today's Habits",
                      action: 'See all',
                      onAction: () => context.go(ARoutes.habits),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 112,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: todayHabits.length,
                        itemBuilder: (_, i) {
                          final habit = todayHabits[i];
                          return _AnimatedEntrance(
                            delay: 400 + (i * 100),
                            play: _hasAnimated,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _HabitDashboardChip(
                                habit: habit,
                                onTap: () => context.go(ARoutes.habits),
                                onToggle: () async {
                                  await ref
                                      .read(habitActionsProvider.notifier)
                                      .toggleToday(habit);
                                  HapticFeedback.lightImpact();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ] else ...[
                SliverToBoxAdapter(
                  child: _AnimatedEntrance(
                    delay: 400,
                    play: _hasAnimated,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _EmptyDashboardMainCard(
                        onQuickAdd: () => context.go(ARoutes.tasks),
                        onTasks: () => context.go(ARoutes.tasks),
                        onHabits: () => context.go(ARoutes.habits),
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── HEADER ───────────────────────────────────────────────────────────────
class _Header extends ConsumerWidget {
  final String greeting;
  final String tagline;
  const _Header({required this.greeting, required this.tagline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notifUnreadCountProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: AText.bodyMedium),
                  const SizedBox(height: 2),
                  // Daily-rotating tagline with a soft fade-in
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (_, v, child) =>
                        Opacity(opacity: v, child: child),
                    child: Text(tagline, style: AText.titleLarge),
                  ),
                ],
              ),
            ),

            // ── Bell button with live badge ────────────────────────────
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                showNotificationCenter(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: unread > 0
                      ? AColors.primary.withAlpha(18)
                      : AColors.bgCard,
                  borderRadius: ARadius.md,
                  border: Border.all(
                    color: unread > 0 ? AColors.primary.withAlpha(80) : AColors.border,
                    width: unread > 0 ? 1.5 : 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      unread > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_outlined,
                      color: unread > 0 ? AColors.primary : AColors.textPrimary,
                      size: 22,
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.elasticOut,
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.shade500,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: AColors.bg, width: 1.5),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(ARoutes.profile);
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AColors.gradientPrimary,
                  borderRadius: ARadius.md,
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── XP CARD ──────────────────────────────────────────────────────────────
class _XpCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;

    final totalXp      = profile?.totalXp ?? 0;
    final level        = profile?.combinedLevel ?? 1;
    final progress     = profile?.combinedProgress ?? 0.0;
    final xpForThis    = profile?.combinedLevelStartXp ?? 0;
    final xpForNext    = profile?.combinedNextLevelXp ?? 300;
    final xpIntoLevel  = totalXp - xpForThis;
    final xpNeeded     = xpForNext;
    final rankTitle    = _rankTitle(level);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A14),
        borderRadius: ARadius.xl,
        border: Border.all(
          color: AColors.primary.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AColors.primary.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ARadius.xl,
        child: Stack(
          children: [
            // Subtle top-left glow orb
            Positioned(
              top: -40,
              left: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AColors.primary.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: rank label + XP counter
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Level pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AColors.primary.withValues(alpha: 0.15),
                          borderRadius: ARadius.full,
                          border: Border.all(
                            color: AColors.primary.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'LVL $level',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$xpIntoLevel / $xpNeeded XP',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Rank title (no emoji)
                  Text(
                    rankTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AColors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${xpNeeded - xpIntoLevel} XP until level ${level + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AColors.textMuted,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Main progress bar
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AColors.primary.withValues(alpha: 0.12),
                          borderRadius: ARadius.full,
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutQuart,
                        builder: (_, val, __) => FractionallySizedBox(
                          widthFactor: val.clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00E88A),
                                  AColors.primary,
                                ],
                              ),
                              borderRadius: ARadius.full,
                              boxShadow: [
                                BoxShadow(
                                  color: AColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Container(
                    height: 1,
                    color: AColors.border.withValues(alpha: 0.5),
                  ),

                  const SizedBox(height: 16),

                  // 3 sphere pips
                  Row(children: [
                    _SpherePip(
                      sphere: XpSphere.willpower,
                      xp: profile?.willpowerXp ?? 0,
                      level: profile?.willpowerLevel ?? 1,
                      progress: profile?.willpowerProgress ?? 0,
                    ),
                    const SizedBox(width: 10),
                    _SpherePip(
                      sphere: XpSphere.intellect,
                      xp: profile?.intellectXp ?? 0,
                      level: profile?.intellectLevel ?? 1,
                      progress: profile?.intellectProgress ?? 0,
                    ),
                    const SizedBox(width: 10),
                    _SpherePip(
                      sphere: XpSphere.health,
                      xp: profile?.healthXp ?? 0,
                      level: profile?.healthLevel ?? 1,
                      progress: profile?.healthProgress ?? 0,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _rankTitle(int level) {
    if (level >= 20) return 'Legendary Achiever';
    if (level >= 15) return 'Elite Performer';
    if (level >= 10) return 'Productivity Master';
    if (level >= 7) return 'Discipline Warrior';
    if (level >= 4) return 'Rising Champion';
    return 'Productivity Rookie';
  }
}

class _SpherePip extends StatelessWidget {
  final XpSphere sphere;
  final int xp, level;
  final double progress;

  const _SpherePip({
    required this.sphere,
    required this.xp,
    required this.level,
    required this.progress,
  });

  // Minimal icon per sphere — no emoji
  IconData get _icon => switch (sphere) {
    XpSphere.willpower => Icons.bolt_rounded,
    XpSphere.intellect => Icons.auto_awesome_rounded,
    XpSphere.health    => Icons.favorite_rounded,
  };

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: sphere.color.withValues(alpha: 0.07),
        borderRadius: ARadius.md,
        border: Border.all(
          color: sphere.color.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 12, color: sphere.color),
              const SizedBox(width: 5),
              Text(
                sphere.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: sphere.color.withValues(alpha: 0.8),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'L$level',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${xp}xp',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: sphere.color.withValues(alpha: 0.15),
                  borderRadius: ARadius.full,
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => FractionallySizedBox(
                  widthFactor: val.clamp(0.0, 1.0),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: sphere.color,
                      borderRadius: ARadius.full,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── FEATURE CARD ─────────────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Color accentColor;
  final IconData icon;
  final String title, subtitle, badge;
  final Color badgeColor;
  final Widget child;

  const _FeatureCard({
    required this.onTap,
    required this.gradient,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.lightImpact();
      },
      child: SizedBox(
        height: 160,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: ARadius.lg,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: ARadius.sm,
                    ),
                    child: Icon(icon, color: accentColor, size: 16),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: ARadius.full,
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: AText.titleSmall.copyWith(color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: AText.bodySmall.copyWith(color: accentColor)),
              const Spacer(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  final String text;
  const _FeaturePlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: ARadius.full,
        ),
        child: Text(
          text,
          style: AText.bodySmall.copyWith(color: Colors.white70),
        ),
      ),
    );
  }
}

// NEW: live info chip for feature cards
class _FeatureLiveStat extends StatelessWidget {
  final String text;
  const _FeatureLiveStat({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: ARadius.full,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          text,
          style: AText.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.lg,
        border: Border.all(color: AColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: AText.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: AText.bodySmall),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title, action;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
    child: Row(
      children: [
        Text(title, style: AText.titleSmall),
        const Spacer(),
        TextButton(
          onPressed: onAction,
          child: Text(
            action,
            style: AText.bodySmall.copyWith(color: AColors.primary),
          ),
        ),
      ],
    ),
  );
}

class _TaskDashboardCard extends StatelessWidget {
  final TaskModel task;
  final Color priorityColor;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskDashboardCard({
    required this.task,
    required this.priorityColor,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: task.done ? AColors.bgElevated : AColors.bgSleek,
          borderRadius: ARadius.lg,
          border: Border.all(
            color: task.done ? AColors.border : AColors.primary.withValues(alpha: 0.2),
          ),
          boxShadow: task.done
              ? null
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 42,
              decoration: BoxDecoration(
                color: task.done
                    ? AColors.textMuted.withValues(alpha: 0.3)
                    : priorityColor,
                borderRadius: ARadius.full,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AText.bodyLarge.copyWith(
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      color: task.done
                          ? AColors.textMuted
                          : AColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (task.category.trim().isNotEmpty)
                        _MiniTag(
                          label: task.category,
                          color: AColors.primary,
                        ),
                      _MiniTag(
                        label: 'P${task.priority}',
                        color: priorityColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle();
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: task.done ? AColors.primary : Colors.transparent,
                  borderRadius: ARadius.sm,
                  border: Border.all(
                    color: task.done ? AColors.primary : AColors.border,
                    width: 1.5,
                  ),
                ),
                child: task.done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitDashboardChip extends StatelessWidget {
  final HabitModel habit;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _HabitDashboardChip({
    required this.habit,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final done = habit.isCompletedToday;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? habit.color.withValues(alpha: 0.08) : AColors.bgSleek,
          borderRadius: ARadius.lg,
          border: Border.all(
            color: done ? habit.color.withValues(alpha: 0.3) : AColors.borderSleek,
          ),
          boxShadow: done
              ? [
            BoxShadow(
              color: habit.color.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done ? habit.color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? habit.color : AColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    )
                        : null,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              habit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AText.bodyMedium.copyWith(
                color: done ? AColors.textMuted : AColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 11,
                  color: habit.streak > 0 ? AColors.warning : AColors.textMuted,
                ),
                const SizedBox(width: 3),
                Text(
                  '${habit.streak > 0 ? habit.streak : 0}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: habit.streak > 0 ? AColors.warning : AColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDashboardMainCard extends StatelessWidget {
  final VoidCallback onQuickAdd;
  final VoidCallback onTasks;
  final VoidCallback onHabits;

  const _EmptyDashboardMainCard({
    required this.onQuickAdd,
    required this.onTasks,
    required this.onHabits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.xl,
        border: Border.all(color: AColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AColors.bgElevated,
              borderRadius: ARadius.md,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: AColors.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text('Your dashboard is empty', style: AText.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Add tasks, habits, and goals to start seeing real data here.',
            style: AText.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onQuickAdd();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                gradient: AColors.gradientPrimary,
                borderRadius: ARadius.full,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Quick Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniActionButton(
                  icon: Icons.checklist_rounded,
                  label: 'Tasks',
                  onTap: onTasks,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniActionButton(
                  icon: Icons.loop_rounded,
                  label: 'Habits',
                  onTap: onHabits,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AColors.bgElevated,
          borderRadius: ARadius.full,
          border: Border.all(color: AColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AColors.textPrimary),
            const SizedBox(width: 8),
            Text(label, style: AText.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: ARadius.full,
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

class _AnimatedEntrance extends StatefulWidget {
  final int delay;
  final bool play;
  final Widget child;

  const _AnimatedEntrance({
    required this.delay,
    required this.play,
    required this.child,
  });

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance> {
  bool _start = false;

  @override
  void initState() {
    super.initState();
    if (widget.play) _trigger();
  }

  @override
  void didUpdateWidget(covariant _AnimatedEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) _trigger();
  }

  void _trigger() {
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _start = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.play) {
      return Opacity(
        opacity: 0,
        child: Transform.translate(
          offset: const Offset(0, 20),
          child: widget.child,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _start ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuint,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: childWidget,
          ),
        );
      },
      child: widget.child,
    );
  }
}