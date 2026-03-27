import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/firestore_service.dart';

// ─── SCREEN ───────────────────────────────────────────────────────────────
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _filterCategory = 'All';

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



  List<GoalModel> _filter(List<GoalModel> src) {
    if (_filterCategory == 'All') return src;
    return src.where((g) => g.category.trim() == _filterCategory).toList();
  }

  double _goalProgress(GoalModel g) {
    if (g.manuallyComplete) return 1.0;
    if (g.steps.isEmpty) return 0.0;
    return g.steps.where((s) => s.done).length / g.steps.length;
  }

  int _goalDoneSteps(GoalModel g) => g.steps.where((s) => s.done).length;

  bool _goalIsComplete(GoalModel g) =>
      g.manuallyComplete || (g.steps.isNotEmpty && g.steps.every((s) => s.done));

  int _goalDaysLeft(GoalModel g) {
    if (g.deadline == null) return -1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(g.deadline!.year, g.deadline!.month, g.deadline!.day);
    return deadline.difference(today).inDays;
  }

  String _goalRewardLabel(GoalModel g) {
    if (g.customReward != null && g.customReward!.trim().isNotEmpty) {
      return g.customReward!.trim();
    }
    if (g.xpReward > 0) return '⭐ ${g.xpReward} XP';
    return '';
  }

  Color _goalColor(GoalModel g) => Color(g.colorValue);

  GoalModel _copyGoal(
      GoalModel g, {
        String? title,
        String? category,
        String? emoji,
        int? colorValue,
        String? note,
        DateTime? deadline,
        List<GoalStepModel>? steps,
        bool? manuallyComplete,
        bool? archived,
        int? xpReward,
        String? customReward,
        double? measureTarget,
        String? measureUnit,
        XpSphere? xpSphere,
      }) {
    return GoalModel(
      id: g.id,
      uid: g.uid,
      title: title ?? g.title,
      category: category ?? g.category,
      emoji: emoji ?? g.emoji,
      colorValue: colorValue ?? g.colorValue,
      note: note ?? g.note,
      deadline: deadline ?? g.deadline,
      steps: steps ?? g.steps,
      xpSphere: xpSphere ?? g.xpSphere,
      xpReward: xpReward ?? g.xpReward,
      customReward: customReward ?? g.customReward,
      measureTarget: measureTarget ?? g.measureTarget,
      measureUnit: measureUnit ?? g.measureUnit,
      archived: archived ?? g.archived,
      manuallyComplete: manuallyComplete ?? g.manuallyComplete,
      createdAt: g.createdAt,
    );
  }

  List<GoalModel> _active(List<GoalModel> goals) =>
      _filter(goals.where((g) => !g.archived && !_goalIsComplete(g)).toList());

  List<GoalModel> _complete(List<GoalModel> goals) =>
      _filter(goals.where((g) => !g.archived && _goalIsComplete(g)).toList());

  List<GoalModel> _all(List<GoalModel> goals) => _filter(goals.where((g) => !g.archived).toList());

  Future<void> _openGoal(String uid, {GoalModel? existing}) async {
    final result = await showModalBottomSheet<GoalModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalEditorSheet(
        uid: uid,
        existing: existing,
        categories: ref.read(allCategoriesProvider),
      ),
    );

    if (result == null) return;

    if (existing != null) {
      await GoalRepository.update(uid, result);
    } else {
      await GoalRepository.create(
        uid,
        title: result.title,
        category: result.category,
        emoji: result.emoji,
        colorValue: result.colorValue,
        note: result.note,
        deadline: result.deadline,
        steps: result.steps,
        xpSphere: result.xpSphere,
        xpReward: result.xpReward,
        customReward: result.customReward,
        measureTarget: result.measureTarget,
        measureUnit: result.measureUnit,
      );
    }
  }

  Future<void> _deleteGoal(String uid, GoalModel g) async {
    await GoalRepository.delete(uid, g.id);
    HapticFeedback.heavyImpact();
  }

  Future<void> _toggleStep(String uid, GoalModel goal, GoalStepModel step) async {
    final updatedSteps = goal.steps
        .map(
          (s) => s.id == step.id
          ? GoalStepModel(id: s.id, title: s.title, done: !s.done)
          : s,
    )
        .toList();

    final wasComplete = _goalIsComplete(goal);
    final updated = _copyGoal(goal, steps: updatedSteps);

    await GoalRepository.update(uid, updated);
    HapticFeedback.lightImpact();

    final nowComplete = _goalIsComplete(updated);
    if (!wasComplete && nowComplete) {
      await ref.read(goalActionsProvider.notifier).markComplete(goal);
      _celebrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal completed: "${goal.title}"'),
            backgroundColor: AColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: ARadius.md),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: const Color(0xFF003D25),
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _markComplete(String uid, GoalModel goal) async {
    if (_goalIsComplete(goal)) return;

    await ref.read(goalActionsProvider.notifier).markComplete(goal);

    _celebrate();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Goal completed: "${goal.title}"'),
        backgroundColor: AColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: ARadius.md),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFF003D25),
          onPressed: () {},
        ),
      ),
    );
  }

  void _celebrate() {
    Future.delayed(const Duration(milliseconds: 0), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 100), HapticFeedback.mediumImpact);
    Future.delayed(const Duration(milliseconds: 200), HapticFeedback.lightImpact);
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
                  debugPrint('Error saving category in Goals: $e');
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
    final uid = ref.watch(currentUidProvider);

    if (uid == null || uid.isEmpty) {
      return const Scaffold(
        backgroundColor: AColors.bg,
        body: SafeArea(
          child: Center(
            child: Text('Sign in to use goals', style: AText.bodyMedium),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AColors.bg,
      body: SafeArea(
        child: StreamBuilder<List<GoalModel>>(
          stream: GoalRepository.stream(uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load goals:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: AText.bodyMedium,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AColors.primary),
              );
            }

            final goals = snapshot.data ?? [];
            final categories = ref.watch(allCategoriesProvider);
            final active = _active(goals);
            final complete = _complete(goals);
            final all = _all(goals);

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Goals', style: AText.displayLarge), // Larger text
                          SizedBox(height: 4),
                          Text(
                            'Define targets. Measure progress.', // More serious copy
                            style: AText.bodyLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _OverallProgress(
                    goals: goals,
                    isComplete: _goalIsComplete,
                    progress: _goalProgress,
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filterCategory == 'All',
                        onTap: () => setState(() => _filterCategory = 'All'),
                      ),
                      ...categories.map(
                            (c) => _FilterChip(
                          label: c,
                          selected: _filterCategory == c,
                          onTap: () => setState(() => _filterCategory = c),
                        ),
                      ),
                      _FilterChip(
                        label: '+ New',
                        selected: false,
                        isAdd: true,
                        onTap: _showAddCategory,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ATabBar(
                    controller: _tabCtrl,
                    tabs: const ['Active', 'Completed', 'All'],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _GoalList(
                        goals: active,
                        onTap: (g) => _openGoal(uid, existing: g),
                        onDelete: (g) => _deleteGoal(uid, g),
                        onToggleStep: (g, step) => _toggleStep(uid, g, step),
                        onMarkComplete: (g) => _markComplete(uid, g),
                        progress: _goalProgress,
                        doneSteps: _goalDoneSteps,
                        isComplete: _goalIsComplete,
                        daysLeft: _goalDaysLeft,
                        rewardLabel: _goalRewardLabel,
                        color: _goalColor,
                      ),
                      _GoalList(
                        goals: complete,
                        onTap: (g) => _openGoal(uid, existing: g),
                        onDelete: (g) => _deleteGoal(uid, g),
                        onToggleStep: (g, step) => _toggleStep(uid, g, step),
                        onMarkComplete: (g) => _markComplete(uid, g),
                        progress: _goalProgress,
                        doneSteps: _goalDoneSteps,
                        isComplete: _goalIsComplete,
                        daysLeft: _goalDaysLeft,
                        rewardLabel: _goalRewardLabel,
                        color: _goalColor,
                      ),
                      _GoalList(
                        goals: all,
                        onTap: (g) => _openGoal(uid, existing: g),
                        onDelete: (g) => _deleteGoal(uid, g),
                        onToggleStep: (g, step) => _toggleStep(uid, g, step),
                        onMarkComplete: (g) => _markComplete(uid, g),
                        progress: _goalProgress,
                        doneSteps: _goalDoneSteps,
                        isComplete: _goalIsComplete,
                        daysLeft: _goalDaysLeft,
                        rewardLabel: _goalRewardLabel,
                        color: _goalColor,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openGoal(uid),
        backgroundColor: AColors.primary,
        foregroundColor: const Color(0xFF003D25),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ─── OVERALL PROGRESS ─────────────────────────────────────────────────────
class _OverallProgress extends StatelessWidget {
  final List<GoalModel> goals;
  final bool Function(GoalModel) isComplete;
  final double Function(GoalModel) progress;

  const _OverallProgress({
    required this.goals,
    required this.isComplete,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();

    final overall = goals.fold(0.0, (sum, g) => sum + progress(g)) / goals.length;
    final done = goals.where(isComplete).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AColors.primary,
            AColors.primary.withValues(alpha: 0.6),
            const Color(0xFF003D25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: ARadius.lg,
        boxShadow: [
          BoxShadow(
            color: AColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Progress',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$done of ${goals.length} goals complete',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: ARadius.full,
                  child: LinearProgressIndicator(
                    value: overall,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: overall,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 5,
                ),
                Text(
                  '${(overall * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GOAL LIST ────────────────────────────────────────────────────────────
class _GoalList extends StatelessWidget {
  final List<GoalModel> goals;
  final Function(GoalModel) onTap;
  final Function(GoalModel) onDelete;
  final Function(GoalModel, GoalStepModel) onToggleStep;
  final Function(GoalModel) onMarkComplete;
  final double Function(GoalModel) progress;
  final int Function(GoalModel) doneSteps;
  final bool Function(GoalModel) isComplete;
  final int Function(GoalModel) daysLeft;
  final String Function(GoalModel) rewardLabel;
  final Color Function(GoalModel) color;

  const _GoalList({
    required this.goals,
    required this.onTap,
    required this.onDelete,
    required this.onToggleStep,
    required this.onMarkComplete,
    required this.progress,
    required this.doneSteps,
    required this.isComplete,
    required this.daysLeft,
    required this.rewardLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_rounded, size: 52, color: AColors.primary),
            SizedBox(height: 16),
            Text('No goals defined', style: AText.titleMedium),
            SizedBox(height: 6),
            Text('Set your targets and track them here.', style: AText.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: goals.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _GoalCard(
          goal: goals[i],
          onTap: () => onTap(goals[i]),
          onDelete: () => onDelete(goals[i]),
          onToggleStep: (step) => onToggleStep(goals[i], step),
          onMarkComplete: () => onMarkComplete(goals[i]),
          progress: progress,
          doneSteps: doneSteps,
          isComplete: isComplete,
          daysLeft: daysLeft,
          rewardLabel: rewardLabel,
          color: color,
        ),
      ),
    );
  }
}

// ─── GOAL CARD ────────────────────────────────────────────────────────────
class _GoalCard extends StatefulWidget {
  final GoalModel goal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkComplete;
  final Function(GoalStepModel) onToggleStep;
  final double Function(GoalModel) progress;
  final int Function(GoalModel) doneSteps;
  final bool Function(GoalModel) isComplete;
  final int Function(GoalModel) daysLeft;
  final String Function(GoalModel) rewardLabel;
  final Color Function(GoalModel) color;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onDelete,
    required this.onToggleStep,
    required this.onMarkComplete,
    required this.progress,
    required this.doneSteps,
    required this.isComplete,
    required this.daysLeft,
    required this.rewardLabel,
    required this.color,
  });

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final goalColor = widget.color(g);
    final left = widget.daysLeft(g);
    final prog = widget.progress(g);
    final complete = widget.isComplete(g);
    final hasSteps = g.steps.isNotEmpty;
    final reward = widget.rewardLabel(g);

    final deadlineColor = left >= 0 && left <= 7
        ? AColors.error
        : left >= 0 && left <= 30
        ? AColors.warning
        : AColors.textMuted;

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: complete ? goalColor.withValues(alpha: 0.06) : null,
          gradient: complete
              ? null
              : LinearGradient(
                  colors: [
                    AColors.bgCard,
                    goalColor.withValues(alpha: 0.05), // subtle tint at the bottom right
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: ARadius.lg,
          border: Border.all(
            color: complete ? goalColor.withValues(alpha: 0.35) : AColors.border,
            width: complete ? 1.5 : 1,
          ),
          boxShadow: !complete
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: goalColor.withValues(alpha: 0.12),
                            borderRadius: ARadius.md,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.data_exploration_rounded, // Better generic goal icon
                              color: goalColor,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(g.title, style: AText.titleSmall)),
                                  if (complete)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: goalColor.withValues(alpha: 0.15),
                                        borderRadius: ARadius.full,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 13,
                                            color: goalColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Completed',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: goalColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: [
                                  if (g.category.trim().isNotEmpty)
                                    _MiniTag(label: g.category, color: goalColor),
                                  if (reward.isNotEmpty)
                                    _MiniTag(
                                      label: reward,
                                      color: const Color(0xFFFFD700),
                                      icon: Icons.card_giftcard_rounded,
                                    ),
                                  if (g.measureTarget != null)
                                    _MiniTag(
                                      label:
                                      'Target: ${g.measureTarget} ${g.measureUnit ?? ''}',
                                      color: AColors.info,
                                      icon: Icons.flag_rounded,
                                    ),
                                  if (g.deadline != null)
                                    _MiniTag(
                                      label: left < 0
                                          ? 'Overdue'
                                          : left == 0
                                          ? 'Due today'
                                          : '$left days left',
                                      color: deadlineColor,
                                      icon: Icons.calendar_today_rounded,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: prog),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, val, __) => ClipRRect(
                              borderRadius: ARadius.full,
                              child: LinearProgressIndicator(
                                value: val,
                                backgroundColor: AColors.border,
                                valueColor: AlwaysStoppedAnimation(goalColor),
                                minHeight: 7,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          hasSteps
                              ? '${widget.doneSteps(g)}/${g.steps.length}'
                              : '${(prog * 100).round()}%',
                          style: AText.bodySmall.copyWith(
                            color: goalColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    if (!complete) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: widget.onMarkComplete,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: goalColor.withValues(alpha: 0.08),
                            borderRadius: ARadius.md,
                            border: Border.all(
                              color: goalColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: goalColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mark as Complete',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: goalColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (hasSteps) ...[
              GestureDetector(
                onTap: () {
                  setState(() => _expanded = !_expanded);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AColors.border)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${g.steps.length} steps  ·  ${widget.doneSteps(g)} done',
                        style: AText.bodySmall,
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: _expanded
                    ? Column(
                  children: [
                    ...g.steps.map(
                          (step) => _StepRow(
                        step: step,
                        color: goalColor,
                        onToggle: () => widget.onToggleStep(step),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
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
              title: const Text('Edit goal', style: AText.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                widget.onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AColors.error),
              title: const Text('Delete goal', style: AText.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── STEP ROW ─────────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final GoalStepModel step;
  final Color color;
  final VoidCallback onToggle;

  const _StepRow({
    required this.step,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: step.done ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: step.done ? color : AColors.border,
                width: 1.5,
              ),
            ),
            child: step.done
                ? const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 13,
            )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.title,
              style: AText.bodyMedium.copyWith(
                color: step.done ? AColors.textMuted : AColors.textSecondary,
                decoration: step.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── GOAL EDITOR ──────────────────────────────────────────────────────────
class _GoalEditorSheet extends StatefulWidget {
  final String uid;
  final GoalModel? existing;
  final List<String> categories;

  const _GoalEditorSheet({
    required this.uid,
    this.existing,
    required this.categories,
  });

  @override
  State<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<_GoalEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _stepCtrl;
  late TextEditingController _measureTargetCtrl;
  late TextEditingController _measureUnitCtrl;
  late TextEditingController _customRewardCtrl;

  late String _emoji;
  String? _category;
  late Color _color;
  DateTime? _deadline;
  bool _useMeasure = false;
  XpSphere? _xpSphereOverride;
  bool _sphereManuallyOverridden = false;

  XpSphere get _effectiveSphere =>
      _xpSphereOverride ?? XpSphereExt.sphereForCategory(_category ?? '');

  final List<GoalStepModel> _steps = [];

  final _emojis = [
    '🎯',
    '📱',
    '🏃',
    '💰',
    '📚',
    '💪',
    '🚀',
    '🎸',
    '✈️',
    '🏠',
    '🎓',
    '💼',
    '🌍',
    '🏆',
    '❤️',
  ];

  final _colors = [
    AColors.primary,
    AColors.info,
    AColors.warning,
    AColors.error,
    const Color(0xFFBF7FF5),
    const Color(0xFFFF8C69),
    const Color(0xFF00D4D4),
    const Color(0xFFFFD700),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _stepCtrl = TextEditingController();
    _measureTargetCtrl = TextEditingController(
      text: e?.measureTarget?.toString() ?? '',
    );
    _measureUnitCtrl = TextEditingController(text: e?.measureUnit ?? '');
    _customRewardCtrl = TextEditingController(text: e?.customReward ?? '');

    _emoji = e?.emoji ?? '🎯';
    _color = e != null ? Color(e.colorValue) : AColors.primary;
    _category = (e?.category != null && e!.category.trim().isNotEmpty)
        ? e.category
        : null;
    _deadline = e?.deadline;
    _useMeasure = e?.measureTarget != null;
    _steps.addAll(
      (e?.steps ?? []).map((s) => GoalStepModel(id: s.id, title: s.title, done: s.done)),
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
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _stepCtrl.dispose();
    _measureTargetCtrl.dispose();
    _measureUnitCtrl.dispose();
    _customRewardCtrl.dispose();
    super.dispose();
  }

  void _pickDeadline() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
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
    if (p != null) setState(() => _deadline = p);
  }

  void _addStep() {
    final value = _stepCtrl.text.trim();
    if (value.isEmpty) return;

    setState(() {
      _steps.add(
        GoalStepModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: value,
          done: false,
        ),
      );
      _stepCtrl.clear();
    });
    HapticFeedback.lightImpact();
  }

  GoalModel _buildGoal() {
    final measure = _useMeasure
        ? double.tryParse(_measureTargetCtrl.text.trim())
        : null;

    return GoalModel(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      uid: widget.uid,
      title: _titleCtrl.text.trim(),
      category: _category?.trim() ?? '',
      emoji: _emoji,
      colorValue: _color.value,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      deadline: _deadline,
      steps: List<GoalStepModel>.from(_steps),
      xpSphere: _effectiveSphere,
      xpReward: 50,
      customReward: _customRewardCtrl.text.trim().isNotEmpty
          ? _customRewardCtrl.text.trim()
          : null,
      measureTarget: _useMeasure ? measure : null,
      measureUnit: _useMeasure && _measureUnitCtrl.text.trim().isNotEmpty
          ? _measureUnitCtrl.text.trim()
          : null,
      archived: widget.existing?.archived ?? false,
      manuallyComplete: widget.existing?.manuallyComplete ?? false,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _buildGoal());
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
          initialChildSize: 0.92,
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
                        style: TextStyle(color: AColors.textMuted, fontSize: 16),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.existing == null ? 'New Goal' : 'Edit Goal',
                      style: AText.titleMedium,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                            controller: _titleCtrl,
                            autofocus: widget.existing == null,
                            style: AText.titleMedium,
                            decoration: const InputDecoration(
                              hintText: 'What is your goal?',
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
                      label: 'Emoji',
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
                          final sel = _color == c;
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
                      label: 'XP Sphere  •  50 XP on completion',
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
                                              color: sphere.color
                                                  .withValues(alpha: 0.7),
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
                      label: 'Measurable Target (optional)',
                      icon: Icons.flag_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() => _useMeasure = !_useMeasure);
                              HapticFeedback.selectionClick();
                            },
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'e.g. "Get 1400 SAT points" or "Run 5 km"',
                                    style: AText.bodySmall,
                                  ),
                                ),
                                _Toggle(
                                  value: _useMeasure,
                                  color: AColors.info,
                                  onTap: () => setState(() => _useMeasure = !_useMeasure),
                                ),
                              ],
                            ),
                          ),
                          if (_useMeasure) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _InputBox(
                                    ctrl: _measureTargetCtrl,
                                    hint: 'Amount  e.g. 1400',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: _InputBox(
                                    ctrl: _measureUnitCtrl,
                                    hint: 'Unit  e.g. points, km, \$',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Deadline',
                      icon: Icons.calendar_month_rounded,
                      child: GestureDetector(
                        onTap: _pickDeadline,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: _deadline != null
                                ? AColors.primaryGlow
                                : AColors.bgCard,
                            borderRadius: ARadius.md,
                            border: Border.all(
                              color: _deadline != null
                                  ? AColors.primary
                                  : AColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: _deadline != null
                                    ? AColors.primary
                                    : AColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _deadline != null
                                    ? DateFormat('EEE, MMM d yyyy').format(_deadline!)
                                    : 'Set a deadline',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _deadline != null
                                      ? AColors.primary
                                      : AColors.textMuted,
                                ),
                              ),
                              const Spacer(),
                              if (_deadline != null)
                                GestureDetector(
                                  onTap: () => setState(() => _deadline = null),
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
                      label: 'Reward on Completion',
                      icon: Icons.card_giftcard_rounded,
                      child: _InputBox(
                        ctrl: _customRewardCtrl,
                        hint: 'e.g. Buy snacks 🍕 or Play games 🎮',
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Steps (optional)',
                      icon: Icons.checklist_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Break your goal into smaller steps',
                            style: AText.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          ..._steps.asMap().entries.map(
                                (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _steps[e.key] = GoalStepModel(
                                          id: e.value.id,
                                          title: e.value.title,
                                          done: !e.value.done,
                                        );
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: e.value.done
                                            ? _color
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: e.value.done
                                              ? _color
                                              : AColors.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: e.value.done
                                          ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      e.value.title,
                                      style: AText.bodyMedium.copyWith(
                                        color: e.value.done
                                            ? AColors.textMuted
                                            : AColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _steps.removeAt(e.key)),
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _stepCtrl,
                                  style: AText.bodyMedium,
                                  onSubmitted: (_) => _addStep(),
                                  decoration: const InputDecoration(
                                    hintText: 'Add a step...',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _addStep,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AColors.primaryGlow,
                                    borderRadius: ARadius.md,
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: AColors.primary,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                          hintText: 'Why does this goal matter to you?',
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

// ─── HELPERS ──────────────────────────────────────────────────────────────
class _InputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;

  const _InputBox({
    required this.ctrl,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: AText.bodyMedium,
    keyboardType: hint.contains('Amount')
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _MiniTag({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: ARadius.full,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAdd;
  final VoidCallback onTap;

  const _FilterChip({
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