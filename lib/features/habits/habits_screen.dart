import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

// ─── SETTINGS ─────────────────────────────────────────────────────────────
final habitsFilterCategoryProvider = StateProvider<String>((ref) => 'All');

// ─── SCREEN ───────────────────────────────────────────────────────────────
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;


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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isHabitWithinDuration(HabitModel habit, DateTime day) {
    final target = _dateOnly(day);
    final start = _dateOnly(habit.createdAt);

    if (target.isBefore(start)) return false;
    if (habit.isUnlimited) return true;
    if (habit.durationDays == null || habit.durationDays! <= 0) return true;

    final endInclusive = start.add(Duration(days: habit.durationDays! - 1));
    return !target.isAfter(endInclusive);
  }

  bool _isHabitScheduledForDay(HabitModel habit, DateTime day) {
    if (habit.scheduleDays.isEmpty) return true;
    return habit.scheduleDays.contains(day.weekday);
  }

  bool _isHabitVisibleToday(HabitModel habit) {
    final now = DateTime.now();
    return !habit.archived &&
        _isHabitWithinDuration(habit, now) &&
        _isHabitScheduledForDay(habit, now);
  }

  bool _matchesCategory(HabitModel habit) {
    final filter = ref.watch(habitsFilterCategoryProvider);
    if (filter == 'All') return true;
    return habit.category.trim() == filter;
  }



  void _toggleHabit(HabitModel h) {
    ref.read(habitActionsProvider.notifier).toggleToday(h);
    HapticFeedback.mediumImpact();
    if (!h.isCompletedToday) _playStreak();
  }

  void _playStreak() {
    Future.delayed(const Duration(milliseconds: 0), HapticFeedback.lightImpact);
    Future.delayed(
        const Duration(milliseconds: 60), HapticFeedback.mediumImpact);
    Future.delayed(const Duration(milliseconds: 120), HapticFeedback.lightImpact);
  }

  void _openAdd({HabitModel? existing}) async {
    final uid = ref.read(currentUidProvider) ?? '';

    final result = await showModalBottomSheet<HabitModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HabitEditorSheet(
        existing: existing,
        uid: uid,
        categories: ref.read(allCategoriesProvider),
      ),
    );

    if (result == null) return;

    if (existing != null) {
      await ref.read(habitActionsProvider.notifier).save(result);
    } else {
      await ref.read(habitActionsProvider.notifier).create(
        name: result.name,
        emoji: result.emoji,
        category: result.category,
        colorValue: result.colorValue,
        scheduleDays: result.scheduleDays,
        xpSphere: result.xpSphere,
        xpReward: result.xpReward,
        note: result.note,
        reminderTime: result.reminderTime,
        isUnlimited: result.isUnlimited,
        durationDays: result.durationDays,
      );
    }
  }

  void _delete(HabitModel h) {
    ref.read(habitActionsProvider.notifier).delete(h.id);
    HapticFeedback.heavyImpact();
  }

  void _showAddCategory() {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AColors.bgElevated,
        shape: const RoundedRectangleBorder(borderRadius: ARadius.xl),
        title: const Text('New Category', style: AText.titleMedium),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AText.bodyLarge,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              final value = ctrl.text.trim();
              if (value.isNotEmpty) {
                try {
                  await ref.read(userActionsProvider.notifier).addCustomCategory(value);
                } catch (e) {
                  debugPrint('Error saving category in Habits: $e');
                }
                if (mounted) Navigator.of(dCtx).pop();
              }
            },
            child: const Text(
              'Add',
              style: TextStyle(color: AColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider).valueOrNull ?? [];
    final visibleHabits = habits.where((h) => !h.archived).toList();
    final categories = ref.watch(allCategoriesProvider);

    final todayHabits = visibleHabits
        .where((h) => _isHabitVisibleToday(h))
        .where(_matchesCategory)
        .toList();

    final allHabits =
    visibleHabits.where(_matchesCategory).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final doneToday = todayHabits.where((h) => h.isCompletedToday).length;
    final totalToday = todayHabits.length;

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Habits', style: AText.displayMedium),
                        Text(
                          totalToday == 0
                              ? 'No habits scheduled for today'
                              : '$doneToday of $totalToday done today',
                          style: AText.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DailyProgress(done: doneToday, total: totalToday),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: ref.watch(habitsFilterCategoryProvider) == 'All',
                    onTap: () => ref.read(habitsFilterCategoryProvider.notifier).state = 'All',
                  ),
                  ...categories.map(
                        (c) => _CategoryChip(
                      label: c,
                      selected: ref.watch(habitsFilterCategoryProvider) == c,
                      onTap: () => ref.read(habitsFilterCategoryProvider.notifier).state = c,
                    ),
                  ),
                  _CategoryChip(
                    label: '+ New',
                    selected: false,
                    onTap: _showAddCategory,
                    isAdd: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ATabBar(
                controller: _tabCtrl,
                tabs: const ['Today', 'All', 'Overview'],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _TodayTab(
                    habits: todayHabits,
                    onToggle: _toggleHabit,
                    onEdit: (h) => _openAdd(existing: h),
                    onDelete: _delete,
                  ),
                  _AllTab(
                    habits: allHabits,
                    onToggle: _toggleHabit,
                    onEdit: (h) => _openAdd(existing: h),
                    onDelete: _delete,
                  ),
                  _OverviewTab(habits: visibleHabits),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        backgroundColor: AColors.primary,
        foregroundColor: const Color(0xFF003D25),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ─── DAILY PROGRESS ───────────────────────────────────────────────────────
class _DailyProgress extends StatelessWidget {
  final int done, total;
  const _DailyProgress({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = done == total && total > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allDone ? AColors.primaryGlow : AColors.bgCard,
        borderRadius: ARadius.lg,
        border: Border.all(
          color: allDone ? AColors.primary : AColors.border,
          width: allDone ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                allDone ? '🎉 All done!' : '${(progress * 100).round()}% complete',
                style: AText.titleSmall.copyWith(
                  color: allDone ? AColors.primary : AColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$done / $total',
                style: AText.bodyMedium.copyWith(color: AColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => ClipRRect(
              borderRadius: ARadius.full,
              child: LinearProgressIndicator(
                value: val,
                backgroundColor: AColors.border,
                valueColor: const AlwaysStoppedAnimation(AColors.primary),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TODAY TAB ────────────────────────────────────────────────────────────
class _TodayTab extends StatelessWidget {
  final List<HabitModel> habits;
  final Function(HabitModel) onToggle, onEdit, onDelete;

  const _TodayTab({
    required this.habits,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌱', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text('No habits scheduled for today', style: AText.titleMedium),
            SizedBox(height: 6),
            Text('Your scheduled habits will show up here.', style: AText.bodyMedium),
          ],
        ),
      );
    }

    final pending = habits.where((h) => !h.isCompletedToday).toList();
    final done = habits.where((h) => h.isCompletedToday).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        if (pending.isNotEmpty) ...[
          ...pending.map(
                (h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HabitCard(
                habit: h,
                onToggle: () => onToggle(h),
                onEdit: () => onEdit(h),
                onDelete: () => onDelete(h),
              ),
            ),
          ),
        ],
        if (done.isNotEmpty) ...[
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: AColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Completed ${done.length}', style: AText.bodySmall),
                  ),
                  const Expanded(child: Divider(color: AColors.border)),
                ],
              ),
            ),
          ...done.map(
                (h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HabitCard(
                habit: h,
                onToggle: () => onToggle(h),
                onEdit: () => onEdit(h),
                onDelete: () => onDelete(h),
              ),
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── ALL TAB ──────────────────────────────────────────────────────────────
class _AllTab extends StatelessWidget {
  final List<HabitModel> habits;
  final Function(HabitModel) onToggle, onEdit, onDelete;

  const _AllTab({
    required this.habits,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📚', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text('No habits yet', style: AText.titleMedium),
            SizedBox(height: 6),
            Text('Create one and it will appear here.', style: AText.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: habits.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _HabitCard(
          habit: habits[i],
          onToggle: () => onToggle(habits[i]),
          onEdit: () => onEdit(habits[i]),
          onDelete: () => onDelete(habits[i]),
        ),
      ),
    );
  }
}

// ─── HABIT CARD ───────────────────────────────────────────────────────────
class _HabitCard extends StatelessWidget {
  final HabitModel habit;
  final VoidCallback onToggle, onEdit, onDelete;

  const _HabitCard({
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  String _scheduleLabel(List<int> scheduleDays) {
    if (scheduleDays.isEmpty) return 'Every day';

    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    return scheduleDays.map((d) => names[d] ?? '?').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final done = habit.isCompletedToday;

    return GestureDetector(
      onTap: onEdit,
      onLongPress: () => _showOptions(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done ? habit.color.withValues(alpha: 0.08) : AColors.bgCard,
          borderRadius: ARadius.lg,
          border: Border.all(
            color: done ? habit.color.withValues(alpha: 0.4) : AColors.border,
            width: done ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: habit.color.withValues(alpha: 0.12),
                borderRadius: ARadius.md,
              ),
              child: Center(
                child: Text(habit.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: AText.titleSmall.copyWith(
                      color: done ? AColors.textMuted : AColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: habit.streak > 0
                              ? AColors.warning.withValues(alpha: 0.12)
                              : AColors.bgElevated,
                          borderRadius: ARadius.full,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              habit.streak > 0 ? '🔥' : '⚪',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${habit.streak} day${habit.streak == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: habit.streak > 0
                                    ? AColors.warning
                                    : AColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _InfoPill(
                        label: _scheduleLabel(habit.scheduleDays),
                        color: AColors.info,
                        icon: Icons.calendar_month_rounded,
                      ),
                      if (habit.category.trim().isNotEmpty)
                        _InfoPill(
                          label: habit.category,
                          color: AColors.primary,
                          icon: Icons.folder_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done ? habit.color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? habit.color : AColors.border,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _last7Dots(HabitModel h) {
    return List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      final isDone = h.isCompletedOn(day);
      final isToday = i == 6;
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          color: isDone ? h.color : AColors.border,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: h.color, width: 1.5) : null,
        ),
      );
    });
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AColors.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AColors.border,
                  borderRadius: ARadius.full,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AColors.primary),
              title: const Text('Edit habit', style: AText.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AColors.error),
              title: const Text('Delete habit', style: AText.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── OVERVIEW TAB ─────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final List<HabitModel> habits;
  const _OverviewTab({required this.habits});

  @override
  Widget build(BuildContext context) {
    final bestStreak = habits.isEmpty
        ? 0
        : habits.map((h) => h.bestStreak).reduce((a, b) => a > b ? a : b);
    final doneToday = habits.where((h) => h.isCompletedToday).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            _StatMini(
              label: 'Total Habits',
              value: '${habits.length}',
              icon: Icons.loop_rounded,
              color: AColors.primary,
            ),
            const SizedBox(width: 12),
            _StatMini(
              label: 'Best Streak',
              value: '${bestStreak}🔥',
              icon: Icons.local_fire_department_rounded,
              color: AColors.warning,
            ),
            const SizedBox(width: 12),
            _StatMini(
              label: 'Done Today',
              value: '$doneToday',
              icon: Icons.check_circle_rounded,
              color: AColors.info,
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...habits.map(
              (h) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _HabitHeatmap(habit: h),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: AText.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: AText.bodySmall),
        ],
      ),
    ),
  );
}

// ─── HABIT HEATMAP ────────────────────────────────────────────────────────
class _HabitHeatmap extends StatelessWidget {
  final HabitModel habit;
  const _HabitHeatmap({required this.habit});

  String _scheduleLabel(List<int> scheduleDays) {
    if (scheduleDays.isEmpty) return 'Every day';

    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    return scheduleDays.map((d) => names[d] ?? '?').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final days =
    List.generate(28, (i) => DateTime.now().subtract(Duration(days: 27 - i)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.lg,
        border: Border.all(color: AColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(habit.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: Text(habit.name, style: AText.titleSmall)),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AColors.warning.withValues(alpha: 0.12),
                  borderRadius: ARadius.full,
                ),
                child: Text(
                  '${habit.streak}🔥 streak',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoPill(
                label: _scheduleLabel(habit.scheduleDays),
                color: AColors.info,
                icon: Icons.calendar_month_rounded,
              ),
              if (habit.category.trim().isNotEmpty)
                _InfoPill(
                  label: habit.category,
                  color: AColors.primary,
                  icon: Icons.folder_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (d) => Expanded(
                child: Center(child: Text(d, style: AText.bodySmall)),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: days.map((day) {
              final done = habit.isCompletedOn(day);
              final isToday = DateUtils.isSameDay(day, DateTime.now());
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: done ? habit.color : AColors.bgElevated,
                  borderRadius: ARadius.sm,
                  border: isToday ? Border.all(color: habit.color, width: 1.5) : null,
                ),
                child: done
                    ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                )
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('28 days', style: AText.bodySmall),
              Text(
                'Best: ${habit.bestStreak} days',
                style: AText.bodySmall.copyWith(color: AColors.warning),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── HABIT EDITOR ─────────────────────────────────────────────────────────
class _HabitEditorSheet extends StatefulWidget {
  final HabitModel? existing;
  final String uid;
  final List<String> categories;

  const _HabitEditorSheet({
    this.existing,
    required this.uid,
    required this.categories,
  });

  @override
  State<_HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<_HabitEditorSheet> {
  late TextEditingController _nameCtrl, _noteCtrl;
  late String _emoji;
  late Color _color;
  String? _category;
  TimeOfDay? _reminderTime;
  List<int> _scheduleDays = [];
  late bool _isUnlimited;
  late TextEditingController _durationCtrl;
  XpSphere? _xpSphereOverride;
  bool _sphereManuallyOverridden = false;

  XpSphere get _effectiveSphere =>
      _xpSphereOverride ?? XpSphereExt.sphereForCategory(_category ?? '');

  final _emojis = [
    '🧘',
    '📚',
    '💪',
    '📝',
    '🚿',
    '🍎',
    '💧',
    '🏃',
    '🎯',
    '🛌',
    '🧠',
    '🎸',
    '🌱',
    '🚴',
    '🍵'
  ];

  final _colors = [
    AColors.primary,
    AColors.info,
    AColors.warning,
    AColors.error,
    const Color(0xFFBF7FF5),
    const Color(0xFFFF8C69),
    const Color(0xFF00D4D4),
    const Color(0xFFFF69B4),
  ];

  final _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _emoji = e?.emoji ?? '🎯';
    _color = e != null ? Color(e.colorValue) : AColors.primary;
    _category = (e?.category != null && e!.category.trim().isNotEmpty)
        ? e.category
        : null;
    _reminderTime = e?.reminderTime;
    _scheduleDays = List.from(e?.scheduleDays ?? []);
    _isUnlimited = e?.isUnlimited ?? true;
    _durationCtrl = TextEditingController(
      text: e?.durationDays != null ? '${e!.durationDays}' : '',
    );
    if (e != null) {
      final autoSphere = XpSphereExt.sphereForCategory(e.category);
      if (e.xpSphere != autoSphere) {
        _xpSphereOverride = e.xpSphere;
        _sphereManuallyOverridden = true;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _pickTime() async {
    final p = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AColors.primary,
            surface: AColors.bgElevated,
            onSurface: AColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _reminderTime = p);
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();

    final e = widget.existing;
    final duration = _isUnlimited ? null : int.tryParse(_durationCtrl.text.trim());

    Navigator.pop(
      context,
      HabitModel(
        id: e?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        uid: widget.uid,
        name: _nameCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        emoji: _emoji,
        colorValue: _color.value,
        category: _category?.trim() ?? '',
        streak: e?.streak ?? 0,
        bestStreak: e?.bestStreak ?? 0,
        scheduleDays: _scheduleDays,
        reminderTime: _reminderTime,
        completionDates: e?.completionDates ?? [],
        xpSphere: _effectiveSphere,
        xpReward: e?.xpReward ?? 15,
        archived: e?.archived ?? false,
        isUnlimited: _isUnlimited,
        durationDays: duration,
        createdAt: e?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AColors.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, ctrl) => Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AColors.border,
                    borderRadius: ARadius.full,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AColors.textMuted,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.existing == null ? 'New Habit' : 'Edit Habit',
                      style: AText.titleMedium,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: AColors.gradientPrimary,
                          borderRadius: ARadius.full,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AColors.border, height: 1),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.15),
                            borderRadius: ARadius.lg,
                          ),
                          child: Center(
                            child: Text(_emoji, style: const TextStyle(fontSize: 30)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            autofocus: widget.existing == null,
                            style: AText.titleMedium,
                            decoration: const InputDecoration(
                              hintText: 'Habit name',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Choose Emoji',
                      icon: Icons.emoji_emotions_rounded,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _emojis.map((e) {
                          final sel = _emoji == e;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _emoji = e);
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: sel
                                    ? _color.withValues(alpha: 0.2)
                                    : AColors.bgCard,
                                borderRadius: ARadius.md,
                                border: Border.all(
                                  color: sel ? _color : AColors.border,
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(e, style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Color',
                      icon: Icons.palette_rounded,
                      child: Row(
                        children: _colors.map((c) {
                          final sel = _color.value == c.value;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _color = c);
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 34,
                              height: 34,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: sel
                                    ? Border.all(color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: sel
                                    ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                                    : null,
                              ),
                              child: sel
                                  ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Category',
                      icon: Icons.folder_rounded,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...widget.categories.map((c) {
                            final sel = _category == c;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _category = c;
                                  if (!_sphereManuallyOverridden) {
                                    _xpSphereOverride = null;
                                  }
                                });
                                HapticFeedback.selectionClick();
                              },
                              onLongPress: () {
                                if (_category == c) {
                                  setState(() => _category = null);
                                  HapticFeedback.selectionClick();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: sel ? AColors.primaryGlow : AColors.bgCard,
                                  borderRadius: ARadius.full,
                                  border: Border.all(
                                    color: sel ? AColors.primary : AColors.border,
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? AColors.primary : AColors.textMuted,
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (_category != null)
                            GestureDetector(
                              onTap: () {
                                setState(() => _category = null);
                                HapticFeedback.selectionClick();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AColors.bgCard,
                                  borderRadius: ARadius.full,
                                  border: Border.all(color: AColors.border),
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── XP Sphere selector ─────────────────────────────
                    _Sec(
                      label: 'XP Sphere  •  15 XP on completion',
                      icon: Icons.auto_awesome_rounded,
                      child: Row(
                        children: XpSphere.values.map((sphere) {
                          final isSelected = _effectiveSphere == sphere;
                          final isAuto = !_sphereManuallyOverridden &&
                              sphere == XpSphereExt.sphereForCategory(_category ?? '');
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: sphere != XpSphere.health ? 8 : 0,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _xpSphereOverride = sphere;
                                    _sphereManuallyOverridden = true;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? sphere.color.withValues(alpha: 0.15)
                                        : AColors.bgCard,
                                    borderRadius: ARadius.md,
                                    border: Border.all(
                                      color: isSelected ? sphere.color : AColors.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(sphere.emoji,
                                          style: const TextStyle(fontSize: 18)),
                                      const SizedBox(height: 4),
                                      Text(
                                        sphere.label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? sphere.color
                                              : AColors.textMuted,
                                        ),
                                      ),
                                      if (isAuto)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'auto',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: sphere.color.withValues(alpha: 0.7),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Schedule',
                      icon: Icons.calendar_month_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Repeat on (empty = every day)',
                            style: AText.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (i) {
                              final day = i + 1;
                              final sel = _scheduleDays.contains(day);
                              return GestureDetector(
                                onTap: () {
                                  setState(() => sel
                                      ? _scheduleDays.remove(day)
                                      : _scheduleDays.add(day));
                                  HapticFeedback.selectionClick();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: sel ? _color : AColors.bgCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: sel ? _color : AColors.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _dayLabels[i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: sel ? Colors.white : AColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Duration',
                      icon: Icons.timelapse_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() => _isUnlimited = !_isUnlimited);
                              HapticFeedback.selectionClick();
                            },
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Unlimited habit', style: AText.bodyLarge),
                                      Text(
                                        'Turn off to set a fixed number of days',
                                        style: AText.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                _Toggle(
                                  value: _isUnlimited,
                                  color: AColors.primary,
                                  onTap: () {
                                    setState(() => _isUnlimited = !_isUnlimited);
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (!_isUnlimited) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _durationCtrl,
                              keyboardType: TextInputType.number,
                              style: AText.bodyMedium,
                              decoration: const InputDecoration(
                                hintText: 'Number of days',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Reminder',
                      icon: Icons.notifications_rounded,
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: _reminderTime != null
                                ? AColors.primaryGlow
                                : AColors.bgCard,
                            borderRadius: ARadius.md,
                            border: Border.all(
                              color: _reminderTime != null
                                  ? AColors.primary
                                  : AColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: _reminderTime != null
                                    ? AColors.primary
                                    : AColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _reminderTime != null
                                    ? _reminderTime!.format(context)
                                    : 'Set daily reminder',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _reminderTime != null
                                      ? AColors.primary
                                      : AColors.textMuted,
                                ),
                              ),
                              const Spacer(),
                              if (_reminderTime != null)
                                GestureDetector(
                                  onTap: () => setState(() => _reminderTime = null),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AColors.textMuted,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Note',
                      icon: Icons.notes_rounded,
                      child: TextField(
                        controller: _noteCtrl,
                        style: AText.bodyMedium,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Why does this habit matter?',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SHARED HELPERS ───────────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _Sec({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 15, color: AColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AText.labelLarge.copyWith(color: AColors.textSecondary),
          ),
        ],
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _ATabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _ATabBar({
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) => Container(
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAdd;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAdd = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      onTap();
      HapticFeedback.selectionClick();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AColors.primaryGlow
            : (isAdd ? Colors.transparent : AColors.bgCard),
        borderRadius: ARadius.full,
        border: Border.all(
          color: selected ? AColors.primary : AColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected
              ? AColors.primary
              : (isAdd ? AColors.textMuted : AColors.textSecondary),
        ),
      ),
    ),
  );
}

class _Toggle extends StatelessWidget {
  final bool value;
  final Color color;
  final VoidCallback onTap;

  const _Toggle({
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 50,
      height: 28,
      decoration: BoxDecoration(
        color: value ? color : AColors.bgCard,
        borderRadius: ARadius.full,
        border: Border.all(color: value ? color : AColors.border),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _InfoPill({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: ARadius.full,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}