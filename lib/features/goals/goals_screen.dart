import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/icon_mapper.dart';
import '../../core/widgets/app_toast.dart';

// в”Ђв”Ђв”Ђ SCREEN в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  late ConfettiController _confetti;
  String _filterCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _confetti.dispose();
    super.dispose();
  }



  List<GoalModel> _filter(List<GoalModel> src) {
    if (_filterCategory == 'All') return src;
    return src.where((g) => g.category.trim() == _filterCategory).toList();
  }

  double _goalProgress(GoalModel g) => g.progress;

  int _goalDoneSteps(GoalModel g) => g.doneMilestones;

  bool _goalIsComplete(GoalModel g) => g.isComplete;

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
    if (g.xpReward > 0) return '${g.xpReward} XP';
    return '';
  }

  Color _goalColor(GoalModel g) => Color(g.colorValue);

  // Just delegate to the model's own copyWith — keeps checkIns/measureCurrent intact
  GoalModel _copyGoal(GoalModel g, {List<GoalStepModel>? steps, bool? manuallyComplete}) =>
      g.copyWith(steps: steps, manuallyComplete: manuallyComplete);


  List<GoalModel> _active(List<GoalModel> goals) =>
      _filter(goals.where((g) => !g.archived && !_goalIsComplete(g)).toList());

  List<GoalModel> _complete(List<GoalModel> goals) =>
      _filter(goals.where((g) => !g.archived && _goalIsComplete(g)).toList());

  List<GoalModel> _all(List<GoalModel> goals) => _filter(goals.where((g) => !g.archived).toList());

  Future<void> _openGoal(String uid, {GoalModel? existing}) async {
    final result = await showModalBottomSheet<GoalModel>(
      context: context,
      useRootNavigator: true,
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
      if (!mounted) return;
      AToast.show(context, 'Goal updated');
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
      if (!mounted) return;
      AToast.show(context, 'Goal created', icon: Icons.flag_rounded);
    }
  }

  Future<void> _deleteGoal(String uid, GoalModel g) async {
    await GoalRepository.delete(uid, g.id);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    AToast.show(context, 'Goal deleted', icon: Icons.delete_rounded, iconColor: AColors.error);
  }

  Future<void> _toggleStep(String uid, GoalModel goal, GoalStepModel step) async {
    final updatedSteps = goal.steps
        .map((s) => s.id == step.id
        ? GoalStepModel(id: s.id, title: s.title, done: !s.done, weight: s.weight)
        : s)
        .toList();

    final wasComplete = _goalIsComplete(goal);
    final updated = _copyGoal(goal, steps: updatedSteps);
    await GoalRepository.update(uid, updated);
    HapticFeedback.lightImpact();

    final nowComplete = _goalIsComplete(updated);
    if (!wasComplete && nowComplete) {
      await ref.read(goalActionsProvider.notifier).markComplete(updated);
      _celebrate();
      if (mounted) {
        AToast.show(context, 'Goal completed! 🎉', icon: Icons.emoji_events_rounded);
      }
    }
  }

  Future<void> _markComplete(String uid, GoalModel goal) async {
    if (_goalIsComplete(goal)) return;
    await ref.read(goalActionsProvider.notifier).markComplete(goal);
    _celebrate();
    if (!mounted) return;
    AToast.show(context, 'Goal completed! 🎉', icon: Icons.emoji_events_rounded);
  }

  Future<void> _checkIn(String uid, GoalModel goal) async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckInSheet(goal: goal, uid: uid),
    );
    if (completed == true && mounted) {
      _celebrate();
      AToast.show(context, 'Goal completed! 🎉', icon: Icons.emoji_events_rounded);
    } else if (mounted && completed != null) {
      AToast.show(context, 'Check-in saved!', icon: Icons.bookmark_added_rounded);
    }
  }

  void _celebrate() {
    _confetti.play();
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
        title: Text('New Category', style: AText.titleMedium),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AText.bodyLarge,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child:       Text(
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
            child:       Text(
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
    // Watch theme providers so this screen rebuilds immediately on theme change.
    ref.watch(themeModeProvider);
    ref.watch(colorThemeProvider);

    final uid = ref.watch(currentUidProvider);

    if (uid == null || uid.isEmpty) {
      return       Scaffold(
        backgroundColor: AColors.bg,
        body: SafeArea(
          child: Center(
            child: Text('Sign in to use goals', style: AText.bodyMedium),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
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
                  return       Center(
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
                    Padding(
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
                          _GoalList(goals: active, onTap: (g) => _openGoal(uid, existing: g),
                              onDelete: (g) => _deleteGoal(uid, g),
                              onToggleStep: (g, step) => _toggleStep(uid, g, step),
                              onMarkComplete: (g) => _markComplete(uid, g),
                              onCheckIn: (g) => _checkIn(uid, g),
                              progress: _goalProgress, doneSteps: _goalDoneSteps,
                              isComplete: _goalIsComplete, daysLeft: _goalDaysLeft,
                              rewardLabel: _goalRewardLabel, color: _goalColor),
                          _GoalList(goals: complete, onTap: (g) => _openGoal(uid, existing: g),
                              onDelete: (g) => _deleteGoal(uid, g),
                              onToggleStep: (g, step) => _toggleStep(uid, g, step),
                              onMarkComplete: (g) => _markComplete(uid, g),
                              onCheckIn: (g) => _checkIn(uid, g),
                              progress: _goalProgress, doneSteps: _goalDoneSteps,
                              isComplete: _goalIsComplete, daysLeft: _goalDaysLeft,
                              rewardLabel: _goalRewardLabel, color: _goalColor),
                          _GoalList(goals: all, onTap: (g) => _openGoal(uid, existing: g),
                              onDelete: (g) => _deleteGoal(uid, g),
                              onToggleStep: (g, step) => _toggleStep(uid, g, step),
                              onMarkComplete: (g) => _markComplete(uid, g),
                              onCheckIn: (g) => _checkIn(uid, g),
                              progress: _goalProgress, doneSteps: _goalDoneSteps,
                              isComplete: _goalIsComplete, daysLeft: _goalDaysLeft,
                              rewardLabel: _goalRewardLabel, color: _goalColor),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: FloatingActionButton(
              onPressed: () => _openGoal(uid),
              backgroundColor: AColors.primary,
              foregroundColor: const Color(0xFF003D25),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
        // ── Confetti overlay ──
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.08,
            numberOfParticles: 20,
            gravity: 0.2,
            shouldLoop: false,
            colors:       [AColors.primary, Color(0xFFFFD700), Color(0xFFBF7FF5),
              Color(0xFF4D9FFF), Colors.white],
          ),
        ),
      ],
    );
  }
}


// в”Ђв”Ђв”Ђ OVERALL PROGRESS в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
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

// в”Ђв”Ђв”Ђ GOAL LIST в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _GoalList extends StatelessWidget {
  final List<GoalModel> goals;
  final Function(GoalModel) onTap;
  final Function(GoalModel) onDelete;
  final Function(GoalModel, GoalStepModel) onToggleStep;
  final Function(GoalModel) onMarkComplete;
  final Function(GoalModel) onCheckIn;
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
    required this.onCheckIn,
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
      return       Center(
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: goals.asMap().entries.map((entry) {
        final i = entry.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _GoalCard(
            goal: goals[i],
            onTap: () => onTap(goals[i]),
            onDelete: () => onDelete(goals[i]),
            onToggleStep: (step) => onToggleStep(goals[i], step),
            onMarkComplete: () => onMarkComplete(goals[i]),
            onCheckIn: () => onCheckIn(goals[i]),
            progress: progress,
            doneSteps: doneSteps,
            isComplete: isComplete,
            daysLeft: daysLeft,
            rewardLabel: rewardLabel,
            color: color,
          ),
        );
      }).toList(),
    );
  }
}

// ─── GOAL CARD ────────────────────────────────────────────────────────────────
class _GoalCard extends StatefulWidget {
  final GoalModel goal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkComplete;
  final VoidCallback onCheckIn;
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
    required this.onCheckIn,
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

  String _fmt(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(1);

  String _lastCheckInLabel(GoalModel g) {
    if (g.checkIns.isEmpty) return '';
    final sorted = [...g.checkIns]..sort((a, b) => b.date.compareTo(a.date));
    final diff = DateTime.now().difference(sorted.first.date).inDays;
    if (diff == 0) return 'Last check-in today';
    if (diff == 1) return 'Last check-in yesterday';
    return 'Last check-in $diff days ago';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final goalColor = widget.color(g);
    final left = widget.daysLeft(g);
    final prog = widget.progress(g);
    final complete = widget.isComplete(g);
    final hasSteps = g.steps.isNotEmpty;
    final hasMeasure = g.measureTarget != null && g.measureTarget! > 0;
    final reward = widget.rewardLabel(g);
    final checkInLabel = _lastCheckInLabel(g);
    final checkInCount = g.checkIns.length;
    final xp = g.computedXpReward;

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
            colors: [AColors.bgCard, goalColor.withValues(alpha: 0.05)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: ARadius.lg,
          border: Border.all(
            color: complete ? goalColor.withValues(alpha: 0.35) : AColors.border,
            width: complete ? 1.5 : 1,
          ),
          boxShadow: !complete
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10, offset: const Offset(0, 4))]
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
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: goalColor.withValues(alpha: 0.12),
                          borderRadius: ARadius.md,
                        ),
                        child: Center(child: AIconMapper.iconWidget(g.emoji, size: 24, color: goalColor)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(g.title, style: AText.titleSmall)),
                          if (complete)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: goalColor.withValues(alpha: 0.15),
                                borderRadius: ARadius.full,
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_circle_rounded, size: 13, color: goalColor),
                                const SizedBox(width: 4),
                                Text('Completed', style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700, color: goalColor)),
                              ]),
                            ),
                        ]),
                        const SizedBox(height: 5),
                        Wrap(spacing: 5, runSpacing: 4, children: [
                          if (g.category.trim().isNotEmpty)
                            _MiniTag(label: g.category, color: goalColor),
                          if (reward.isNotEmpty)
                            _MiniTag(label: reward, color: const Color(0xFFFFD700),
                                icon: Icons.card_giftcard_rounded),
                          if (hasMeasure)
                            _MiniTag(
                                label: '${_fmt(g.measureCurrent)} / ${_fmt(g.measureTarget!)} ${g.measureUnit ?? ""}',
                                color: AColors.info, icon: Icons.trending_up_rounded),
                          if (g.deadline != null)
                            _MiniTag(
                                label: left < 0 ? 'Overdue' : left == 0 ? 'Due today' : '$left days left',
                                color: deadlineColor, icon: Icons.calendar_today_rounded),
                        ]),
                      ])),
                    ]),

                    const SizedBox(height: 14),

                    // Only show progress bar when there is something to track
                    if (hasSteps || hasMeasure) Row(children: [
                      Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: prog),
                          key: ValueKey(prog),
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
                            color: goalColor, fontWeight: FontWeight.w700),
                      ),
                    ]),

                    if (checkInCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.bookmark_rounded, size: 11,
                            color: goalColor.withValues(alpha: 0.65)),
                        const SizedBox(width: 4),
                        Text(
                          checkInLabel.isNotEmpty
                              ? '$checkInLabel  \xb7  $checkInCount check-in${checkInCount == 1 ? '' : 's'}'
                              : '$checkInCount check-in${checkInCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11,
                              color: goalColor.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ],

                    if (!complete) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: widget.onCheckIn,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [goalColor.withValues(alpha: 0.18),
                                goalColor.withValues(alpha: 0.07)],
                              begin: Alignment.centerLeft, end: Alignment.centerRight,
                            ),
                            borderRadius: ARadius.md,
                            border: Border.all(color: goalColor.withValues(alpha: 0.35)),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_circle_outline_rounded, color: goalColor, size: 16),
                            const SizedBox(width: 6),
                            Text('Check In', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: goalColor)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: goalColor.withValues(alpha: 0.15),
                                borderRadius: ARadius.full,
                              ),
                              child: Text('$xp XP', style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w800, color: goalColor)),
                            ),
                          ]),
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
                  decoration:       BoxDecoration(
                      border: Border(top: BorderSide(color: AColors.border))),
                  child: Row(children: [
                    Text(
                        '${g.steps.length} milestone${g.steps.length == 1 ? '' : 's'}  \xb7  ${widget.doneSteps(g)} done',
                        style: AText.bodySmall),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child:       Icon(Icons.keyboard_arrow_down_rounded,
                          color: AColors.textMuted, size: 18),
                    ),
                  ]),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: _expanded
                    ? Column(children: [
                  ...g.steps.map((step) => _StepRow(
                      step: step, color: goalColor,
                      onToggle: () => widget.onToggleStep(step))),
                  const SizedBox(height: 6),
                ])
                    : const SizedBox.shrink(),
              ),
            ],

            if (g.checkIns.isNotEmpty)
              _CheckInTimeline(goal: g, color: goalColor),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration:       BoxDecoration(
          color: AColors.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AColors.border, borderRadius: ARadius.full))),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.edit_rounded, color: AColors.primary),
            title: Text('Edit goal', style: AText.bodyLarge),
            onTap: () { Navigator.pop(context); widget.onTap(); },
          ),
          if (!widget.isComplete(widget.goal))
            ListTile(
              leading: Icon(Icons.check_circle_rounded, color: AColors.primary),
              title: Text('Mark as Complete', style: AText.bodyLarge),
              subtitle:       Text('Override progress and finish the goal',
                  style: AText.bodySmall),
              onTap: () { Navigator.pop(context); widget.onMarkComplete(); },
            ),
          ListTile(
            leading: Icon(Icons.delete_rounded, color: AColors.error),
            title: Text('Delete goal', style: AText.bodyLarge),
            onTap: () { Navigator.pop(context); widget.onDelete(); },
          ),
        ]),
      ),
    );
  }
}

// в”Ђв”Ђв”Ђ STEP ROW в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _StepRow extends StatelessWidget {
  final GoalStepModel step;
  final Color color;
  final VoidCallback onToggle;

  const _StepRow({required this.step, required this.color, required this.onToggle});

  String get _weightLabel => switch (step.weight) {
    1 => 'S', 2 => 'M', 3 => 'L', _ => 'S'
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: step.done ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: step.done ? color : AColors.border, width: 1.5),
          ),
          child: step.done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(step.title, style: AText.bodyMedium.copyWith(
          color: step.done ? AColors.textMuted : AColors.textSecondary,
          decoration: step.done ? TextDecoration.lineThrough : null,
        ))),
        const SizedBox(width: 8),
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: color.withValues(alpha: step.done ? 0.08 : 0.14),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(_weightLabel, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: color.withValues(alpha: step.done ? 0.4 : 0.85)))),
        ),
      ]),
    ),
  );
}

// ─── CHECK-IN TIMELINE ────────────────────────────────────────────────────────
class _CheckInTimeline extends StatelessWidget {
  final GoalModel goal;
  final Color color;

  const _CheckInTimeline({required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final sorted = [...goal.checkIns]..sort((a, b) => b.date.compareTo(a.date));
    final visible = sorted.take(10).toList();
    final hasMeasure = goal.measureTarget != null;

    return Container(
      decoration:       BoxDecoration(
          border: Border(top: BorderSide(color: AColors.border))),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history_rounded, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text('Check-in history', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7))),
          if (goal.checkIns.length > 10) ...[
            const Spacer(),
            Text('showing last 10', style: AText.bodySmall),
          ],
        ]),
        const SizedBox(height: 8),
        ...visible.map((ci) {
          final dateStr = DateFormat('MMM d').format(ci.date);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.5), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ci.note, style: AText.bodySmall.copyWith(
                    color: AColors.textSecondary)),
                Row(children: [
                  Text(dateStr, style: AText.bodySmall),
                  if (hasMeasure && ci.progressDelta != null && ci.progressDelta! > 0) ...[
                    const SizedBox(width: 8),
                    Text('+${ci.progressDelta!.toStringAsFixed(ci.progressDelta!.truncateToDouble() == ci.progressDelta ? 0 : 1)} ${goal.measureUnit ?? ""}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: color.withValues(alpha: 0.75))),
                  ],
                ]),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─── CHECK-IN SHEET ───────────────────────────────────────────────────────────
class _CheckInSheet extends ConsumerStatefulWidget {
  final GoalModel goal;
  final String uid;

  const _CheckInSheet({required this.goal, required this.uid});

  @override
  ConsumerState<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<_CheckInSheet> {
  final _noteCtrl = TextEditingController();
  final _deltaCtrl = TextEditingController();
  bool _saving = false;

  bool get _hasMeasure =>
      widget.goal.measureTarget != null && widget.goal.measureTarget! > 0;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _deltaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;

    setState(() => _saving = true);
    try {
      double? delta;
      if (_hasMeasure && _deltaCtrl.text.trim().isNotEmpty) {
        delta = double.tryParse(_deltaCtrl.text.trim());
      }

      final completed = await ref.read(goalActionsProvider.notifier)
          .addCheckIn(widget.goal, note, delta);

      if (mounted) Navigator.pop(context, completed ? true : false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final goalColor = Color(g.colorValue);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration:       BoxDecoration(
        color: AColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPad),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AColors.border, borderRadius: ARadius.full))),
        const SizedBox(height: 20),
        Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(
                  color: goalColor.withValues(alpha: 0.12), borderRadius: ARadius.sm),
              child: Center(child: AIconMapper.iconWidget(g.emoji, size: 18, color: goalColor))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Check In', style: AText.titleSmall),
            Text(g.title, style: AText.bodySmall),
          ])),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _noteCtrl,
          autofocus: true,
          maxLines: 3,
          style: AText.bodyMedium,
          decoration: InputDecoration(
            hintText: 'What did you do toward this goal?',
            hintStyle: AText.bodyMedium.copyWith(color: AColors.textMuted),
            filled: true, fillColor: AColors.bgCard,
            border: OutlineInputBorder(
                borderRadius: ARadius.md,
                borderSide: BorderSide(color: AColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: ARadius.md,
                borderSide: BorderSide(color: AColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: ARadius.md,
                borderSide: BorderSide(color: goalColor, width: 1.5)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        if (_hasMeasure) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _deltaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AText.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Progress added (e.g. 5.2 ${g.measureUnit ?? "units"})',
              hintStyle: AText.bodyMedium.copyWith(color: AColors.textMuted),
              prefixIcon: Icon(Icons.trending_up_rounded, color: goalColor, size: 18),
              filled: true, fillColor: AColors.bgCard,
              border: OutlineInputBorder(
                  borderRadius: ARadius.md,
                  borderSide: BorderSide(color: AColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: ARadius.md,
                  borderSide: BorderSide(color: AColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: ARadius.md,
                  borderSide: BorderSide(color: goalColor, width: 1.5)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                '${g.measureCurrent} / ${g.measureTarget} ${g.measureUnit ?? ""} so far',
                style: TextStyle(fontSize: 11, color: goalColor, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: goalColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: ARadius.md),
            ),
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Check-In', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}



// в”Ђв”Ђв”Ђ GOAL EDITOR в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
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
  int _pendingWeight = 1; // 1=Small, 2=Medium, 3=Large

  static const List<String> _allEmojis = [
    '🎯', '📱', '🏃', '💰', '📚',
    '💪', '🚀', '🎸', '✈️', '🏠',
    '🎓', '💼', '🌍', '🏆', '❤️',
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
      (e?.steps ?? []).map((s) => GoalStepModel(id: s.id, title: s.title, done: s.done, weight: s.weight)),
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
          colorScheme:       ColorScheme.dark(
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
          weight: _pendingWeight,
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

    final e = widget.existing;

    // When editing, preserve check-in history and measurable progress
    // so that editing a goal never wipes runtime data
    return GoalModel(
      id: e?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
      archived: e?.archived ?? false,
      manuallyComplete: e?.manuallyComplete ?? false,
      createdAt: e?.createdAt ?? DateTime.now(),
      // ↓ Always carry over runtime data that the editor doesn't touch
      checkIns: e?.checkIns ?? const [],
      measureCurrent: e?.measureCurrent ?? 0,
    );
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      AToast.show(context, 'Please enter a title for your goal');
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _buildGoal());
  }

  @override
  Widget build(BuildContext context) {
    final iconData = AIconMapper.resolve(_emoji);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration:       BoxDecoration(
          color: AColors.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, ctrl) => Column(
            children: [
              const SizedBox(height: 10),
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AColors.border, borderRadius: ARadius.full))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close_rounded, color: AColors.textMuted, size: 24)),
                  const Spacer(),
                  Text(widget.existing == null ? 'New Goal' : 'Edit Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AColors.textPrimary, letterSpacing: -0.3)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(gradient: AColors.gradientPrimary, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [

                    // в”Ѓв”Ѓ CARD 1: Title + Appearance в”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓ
                    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                          child: Center(child: iconData != null ? Icon(iconData, size: 24, color: _color) : Text(_emoji, style: const TextStyle(fontSize: 24))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(
                          controller: _titleCtrl, autofocus: widget.existing == null,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'What is your goal?',
                            hintStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AColors.textMuted.withValues(alpha: 0.5)),
                            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        )),
                      ]),
                      const SizedBox(height: 16),
                      _label('ICON'),
                      const SizedBox(height: 8),
                      SizedBox(height: 42, child: ListView.separated(
                        scrollDirection: Axis.horizontal, itemCount: _allEmojis.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final e = _allEmojis[i]; final sel = _emoji == e; final mapped = AIconMapper.resolve(e);
                          return GestureDetector(
                            onTap: () { setState(() => _emoji = e); HapticFeedback.selectionClick(); },
                            child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: sel ? _color.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sel ? _color : AColors.border.withValues(alpha: 0.4), width: sel ? 1.5 : 1),
                              ),
                              child: Center(child: mapped != null ? Icon(mapped, size: 19, color: sel ? _color : AColors.textMuted) : Text(e, style: const TextStyle(fontSize: 19))),
                            ),
                          );
                        },
                      )),
                      const SizedBox(height: 14),
                      _label('COLOR'),
                      const SizedBox(height: 8),
                      SizedBox(height: 28, child: ListView.separated(
                        scrollDirection: Axis.horizontal, itemCount: _colors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final c = _colors[i]; final sel = _color.toARGB32() == c.toARGB32();
                          return GestureDetector(
                            onTap: () { setState(() => _color = c); HapticFeedback.selectionClick(); },
                            child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 28, height: 28,
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                                border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2.5),
                                boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 10, spreadRadius: 1)] : null,
                              ),
                              child: sel ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                            ),
                          );
                        },
                      )),
                    ])),

                    const SizedBox(height: 10),

                    // в”Ѓв”Ѓ CARD 2: Category + XP в”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓ
                    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('CATEGORY'),
                      const SizedBox(height: 8),
                      SizedBox(height: 34, child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.categories.length + (_category != null ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          if (_category != null && i == widget.categories.length) {
                            return GestureDetector(onTap: () => setState(() => _category = null),
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AColors.error.withValues(alpha: 0.3))),
                                child: Center(child: Icon(Icons.close_rounded, size: 14, color: AColors.error)),
                              ),
                            );
                          }
                          final c = widget.categories[i]; final sel = _category == c;
                          return GestureDetector(
                            onTap: () => setState(() { _category = c; if (!_sphereManuallyOverridden) _xpSphereOverride = null; }),
                            child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: sel ? _color.withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: sel ? _color : AColors.border.withValues(alpha: 0.4)),
                              ),
                              child: Center(child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? _color : AColors.textMuted))),
                            ),
                          );
                        },
                      )),
                      const SizedBox(height: 14),
                      Row(children: [_label('XP SPHERE'), const Spacer(), Text('50 XP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AColors.primary.withValues(alpha: 0.7)))]),
                      const SizedBox(height: 8),
                      SizedBox(height: 34, child: ListView.separated(
                        scrollDirection: Axis.horizontal, itemCount: XpSphere.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final s = XpSphere.values[i]; final sel = _effectiveSphere == s;
                          return GestureDetector(
                            onTap: () { HapticFeedback.selectionClick(); setState(() { _xpSphereOverride = s; _sphereManuallyOverridden = true; }); },
                            child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: sel ? s.color.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? s.color : AColors.border.withValues(alpha: 0.4))),
                              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(s.icon, size: 16, color: sel ? s.color : AColors.textMuted), const SizedBox(width: 5),
                                Text(s.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? s.color : AColors.textMuted)),
                              ])),
                            ),
                          );
                        },
                      )),
                    ])),

                    const SizedBox(height: 10),

                    // в”Ѓв”Ѓ CARD 3: Deadline + Measure + Reward в”Ѓв”Ѓв”Ѓв”Ѓв”Ѓ
                    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      GestureDetector(onTap: _pickDeadline, child: Row(children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: _deadline != null ? _color : AColors.textMuted),
                        const SizedBox(width: 8),
                        Text(_deadline != null ? DateFormat('EEE, MMM d yyyy').format(_deadline!) : 'Deadline',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _deadline != null ? _color : AColors.textMuted)),
                        const Spacer(),
                        if (_deadline != null) GestureDetector(onTap: () => setState(() => _deadline = null), child: Icon(Icons.close_rounded, size: 16, color: AColors.textMuted))
                        else Icon(Icons.chevron_right_rounded, size: 18, color: AColors.textMuted.withValues(alpha: 0.5)),
                      ])),
                      const SizedBox(height: 12), Divider(color: AColors.border, height: 1), const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () { setState(() => _useMeasure = !_useMeasure); HapticFeedback.selectionClick(); },
                        child: Row(children: [
                          Expanded(child: Text('Measurable target', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AColors.textSecondary))),
                          _Toggle(value: _useMeasure, color: _color, onTap: () => setState(() => _useMeasure = !_useMeasure)),
                        ]),
                      ),
                      if (_useMeasure) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(flex: 2, child: _InputBox(ctrl: _measureTargetCtrl, hint: 'Amount')),
                          const SizedBox(width: 8),
                          Expanded(flex: 3, child: _InputBox(ctrl: _measureUnitCtrl, hint: 'Unit (km, pts...)')),
                        ]),
                      ],
                      const SizedBox(height: 12), Divider(color: AColors.border, height: 1), const SizedBox(height: 12),
                      Row(children: [
                        Icon(Icons.card_giftcard_rounded, size: 18, color: AColors.textMuted.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _customRewardCtrl,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AColors.textPrimary),
                          decoration: InputDecoration(hintText: 'Reward on completion',
                              hintStyle: TextStyle(color: AColors.textMuted.withValues(alpha: 0.5)),
                              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent, isDense: true, contentPadding: EdgeInsets.zero),
                        )),
                      ]),
                    ])),

                    const SizedBox(height: 10),

                    // Milestones card
                    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('MILESTONES'),
                      const SizedBox(height: 4),
                      Text('Tap a milestone to toggle done. Tap the badge to cycle weight.', style: TextStyle(fontSize: 11, color: AColors.textMuted)),
                      const SizedBox(height: 10),
                      ..._steps.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          GestureDetector(
                            onTap: () { setState(() { _steps[e.key] = GoalStepModel(id: e.value.id, title: e.value.title, done: !e.value.done, weight: e.value.weight); }); HapticFeedback.selectionClick(); },
                            child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 20, height: 20,
                              decoration: BoxDecoration(color: e.value.done ? _color : Colors.transparent, shape: BoxShape.circle,
                                  border: Border.all(color: e.value.done ? _color : AColors.border, width: 1.5)),
                              child: e.value.done ? const Icon(Icons.check_rounded, color: Colors.white, size: 12) : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.value.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                              color: e.value.done ? AColors.textMuted : AColors.textSecondary,
                              decoration: e.value.done ? TextDecoration.lineThrough : null))),
                          // Weight badge — tap to cycle S -> M -> L -> S
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                final next = (e.value.weight % 3) + 1;
                                _steps[e.key] = e.value.copyWith(weight: next);
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: _color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text(
                                e.value.weight == 1 ? 'S' : e.value.weight == 2 ? 'M' : 'L',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _color),
                              )),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(onTap: () => setState(() => _steps.removeAt(e.key)),
                              child: Icon(Icons.close_rounded, color: AColors.textMuted, size: 16)),
                        ]),
                      )),
                      const SizedBox(height: 8),
                      // Weight selector for NEW step
                      Row(children: [
                        Text('Weight:', style: TextStyle(fontSize: 12, color: AColors.textMuted)),
                        const SizedBox(width: 8),
                        ...([1, 2, 3]).map((w) {
                          final label = w == 1 ? 'S' : w == 2 ? 'M' : 'L';
                          final sel = _pendingWeight == w;
                          return GestureDetector(
                            onTap: () { setState(() => _pendingWeight = w); HapticFeedback.selectionClick(); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 6),
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: sel ? _color.withValues(alpha: 0.15) : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: sel ? _color : AColors.border, width: 1.5),
                              ),
                              child: Center(child: Text(label,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                      color: sel ? _color : AColors.textMuted))),
                            ),
                          );
                        }),
                        const SizedBox(width: 4),
                        Expanded(child: TextField(controller: _stepCtrl,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AColors.textPrimary),
                          onSubmitted: (_) => _addStep(),
                          decoration: InputDecoration(hintText: 'Add a milestone...',
                              hintStyle: TextStyle(color: AColors.textMuted.withValues(alpha: 0.5)),
                              filled: true, fillColor: AColors.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), isDense: true),
                        )),
                        const SizedBox(width: 8),
                        GestureDetector(onTap: _addStep, child: Container(width: 36, height: 36,
                            decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.add_rounded, color: _color, size: 20))),
                      ]),
                    ])),

                    const SizedBox(height: 10),

                    // в”Ѓв”Ѓ CARD 5: Note в”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓв”Ѓ
                    _card(child: TextField(controller: _noteCtrl,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AColors.textSecondary),
                      maxLines: 3, minLines: 1,
                      decoration: InputDecoration(hintText: 'Add a note...',
                          hintStyle: TextStyle(color: AColors.textMuted.withValues(alpha: 0.4)),
                          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent, isDense: true, contentPadding: EdgeInsets.zero),
                    )),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AColors.bgCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AColors.border.withValues(alpha: 0.35))),
    child: child,
  );

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AColors.textMuted.withValues(alpha: 0.55)));
}

// ─── HELPERS ──────────────────────────────────────────────────────────────
class _InputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;

  const _InputBox({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AColors.textPrimary),
    keyboardType: hint.contains('Amount')
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AColors.textMuted.withValues(alpha: 0.5)),
      filled: true, fillColor: AColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    ),
  );
}

class _Toggle extends StatelessWidget {
  final bool value;
  final Color color;
  final VoidCallback onTap;

  const _Toggle({required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 50, height: 28,
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
          width: 22, height: 22,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    ),
  );
}

class _Sec extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _Sec({required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 15, color: AColors.primary),
        const SizedBox(width: 6),
        Text(label, style: AText.labelLarge.copyWith(color: AColors.textSecondary)),
      ]),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _MiniTag({required this.label, required this.color, this.icon});

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
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAdd;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.isAdd = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { onTap(); HapticFeedback.selectionClick(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AColors.primaryGlow : (isAdd ? Colors.transparent : AColors.bgCard),
        borderRadius: ARadius.full,
        border: Border.all(color: selected ? AColors.primary : AColors.border, width: selected ? 1.5 : 1),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: selected ? AColors.primary : (isAdd ? AColors.textMuted : AColors.textSecondary),
      )),
    ),
  );
}

class _ATabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _ATabBar({required this.controller, required this.tabs});

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
      indicator: BoxDecoration(gradient: AColors.gradientPrimary, borderRadius: ARadius.md),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: AText.labelLarge,
      labelColor: Colors.white,
      unselectedLabelColor: AColors.textMuted,
      tabs: tabs.map((t) => Tab(text: t)).toList(),
    ),
  );
}

class _HScrollItem {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _HScrollItem({required this.label, required this.selected, required this.onTap});
}

class _HScrollSelector extends StatelessWidget {
  final List<_HScrollItem> items;
  const _HScrollSelector({required this.items});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        ...items.map((item) => GestureDetector(
          onTap: () { item.onTap(); HapticFeedback.selectionClick(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: item.selected ? AColors.primaryGlow : AColors.bgCard,
              borderRadius: ARadius.full,
              border: Border.all(color: item.selected ? AColors.primary : AColors.border, width: item.selected ? 1.5 : 1),
            ),
            child: Text(item.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: item.selected ? AColors.primary : AColors.textMuted)),
          ),
        )),
      ],
    ),
  );
}