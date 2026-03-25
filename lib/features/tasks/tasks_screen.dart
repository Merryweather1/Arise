import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

// ─── SORT OPTIONS ─────────────────────────────────────────────────────────
enum SortMode { date, priority }
enum DisplayMode { cards, calendar }

// ─── SCREEN ───────────────────────────────────────────────────────────────
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  SortMode _sortMode = SortMode.date;
  DisplayMode _displayMode = DisplayMode.cards;
  bool _hideCompleted = false;
  String _filterCategory = 'All';
  DateTime _calendarDate = DateTime.now();

  List<String> _categories = [
    'Personal',
    'Work',
    'Health',
    'Learning',
    'Finance',
    'Family',
  ];

  List<TaskModel> _filtered(List<TaskModel> src) {
    final list = src.where((t) {
      final category = t.category.trim();

      if (_hideCompleted && t.done) return false;
      if (_filterCategory != 'All' && category != _filterCategory) return false;

      return true;
    }).toList();

    list.sort((a, b) {
      if (_sortMode == SortMode.priority) {
        return b.priority.compareTo(a.priority);
      }

      final aDate = a.dueDate ?? DateTime(2099);
      final bDate = b.dueDate ?? DateTime(2099);
      return aDate.compareTo(bDate);
    });

    return list;
  }

  List<TaskModel> get _cardsFiltered {
    final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
    return _filtered(tasks);
  }

  List<TaskModel> get _calendarFiltered {
    final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
    return _filtered(
      tasks
          .where(
            (t) =>
        t.dueDate != null &&
            DateUtils.isSameDay(t.dueDate!, _calendarDate),
      )
          .toList(),
    );
  }

  Future<void> _complete(TaskModel t) async {
    await ref.read(taskActionsProvider.notifier).setDone(t, true);
    HapticFeedback.mediumImpact();
    _playTick();
  }

  Future<void> _undo(TaskModel t) async {
    await ref.read(taskActionsProvider.notifier).setDone(t, false);
    HapticFeedback.lightImpact();
  }

  Future<void> _delete(TaskModel t) async {
    await ref.read(taskActionsProvider.notifier).delete(t.id);
    HapticFeedback.heavyImpact();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task deleted'),
        backgroundColor: AColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: ARadius.md),
      ),
    );
  }

  void _playTick() {
    Future.delayed(
      const Duration(milliseconds: 0),
      HapticFeedback.lightImpact,
    );
    Future.delayed(
      const Duration(milliseconds: 80),
      HapticFeedback.mediumImpact,
    );
  }

  Future<void> _openTask({TaskModel? existing}) async {
    final uid = ref.read(currentUidProvider) ?? '';
    final result = await showModalBottomSheet<TaskModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskEditorSheet(
        existing: existing,
        categories: _categories,
        uid: uid,
      ),
    );

    if (result == null) return;

    if (existing != null) {
      await ref.read(taskActionsProvider.notifier).save(result);
    } else {
      await ref.read(taskActionsProvider.notifier).create(result);
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(
        sortMode: _sortMode,
        displayMode: _displayMode,
        hideCompleted: _hideCompleted,
        onSortChanged: (v) => setState(() => _sortMode = v),
        onDisplayChanged: (v) => setState(() => _displayMode = v),
        onHideChanged: (v) => setState(() => _hideCompleted = v),
      ),
    );
  }

  void _showAddCategory() {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(dCtx).viewInsets.bottom,
        ),
        child: AlertDialog(
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
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() => _categories.add(ctrl.text.trim()));
                  Navigator.of(dCtx).pop();
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(color: AColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskActions(TaskModel task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AColors.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
            Text(
              task.title,
              style: AText.titleMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_rounded, color: AColors.primary),
              title: const Text('Edit task', style: AText.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _openTask(existing: task);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_rounded, color: AColors.error),
              title: const Text('Delete task', style: AText.bodyLarge),
              onTap: () async {
                Navigator.pop(context);
                await _delete(task);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

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
                        Text('Tasks', style: AText.displayMedium),
                        Text(
                          'Stay on top of your day',
                          style: AText.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(icon: Icons.tune_rounded, onTap: _showSettings),
                ],
              ),
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
                    selected: _filterCategory == 'All',
                    onTap: () => setState(() => _filterCategory = 'All'),
                  ),
                  ..._categories.map(
                        (c) => _CategoryChip(
                      label: c,
                      selected: _filterCategory == c,
                      onTap: () => setState(() => _filterCategory = c),
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

            if (_displayMode == DisplayMode.calendar) ...[
              _CalendarStrip(
                selected: _calendarDate,
                onSelect: (d) => setState(() => _calendarDate = d),
              ),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: tasksAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AColors.primary),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load tasks:\n$error',
                      textAlign: TextAlign.center,
                      style: AText.bodyMedium,
                    ),
                  ),
                ),
                data: (_) {
                  return _displayMode == DisplayMode.cards
                      ? _TaskList(
                    tasks: _cardsFiltered,
                    onComplete: _complete,
                    onUndo: _undo,
                    onDelete: _delete,
                    onTap: (t) => _openTask(existing: t),
                    onLongPress: _showTaskActions,
                  )
                      : _TaskList(
                    tasks: _calendarFiltered,
                    onComplete: _complete,
                    onUndo: _undo,
                    onDelete: _delete,
                    onTap: (t) => _openTask(existing: t),
                    onLongPress: _showTaskActions,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTask(),
        backgroundColor: AColors.primary,
        foregroundColor: const Color(0xFF003D25),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ─── CALENDAR STRIP ───────────────────────────────────────────────────────
class _CalendarStrip extends StatefulWidget {
  final DateTime selected;
  final Function(DateTime) onSelect;

  const _CalendarStrip({
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  late ScrollController _scrollCtrl;

  final List<DateTime> _dates = List.generate(
    60,
        (i) => DateTime.now()
        .subtract(const Duration(days: 7))
        .add(Duration(days: i)),
  );

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController(initialScrollOffset: 7 * 64.0);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _dates.length,
        itemBuilder: (_, i) {
          final d = _dates[i];
          final isSelected = DateUtils.isSameDay(d, widget.selected);
          final isToday = DateUtils.isSameDay(d, DateTime.now());

          return GestureDetector(
            onTap: () {
              widget.onSelect(d);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? AColors.gradientPrimary : null,
                color: isSelected
                    ? null
                    : (isToday ? AColors.primaryGlow : AColors.bgCard),
                borderRadius: ARadius.lg,
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isToday ? AColors.primary : AColors.border),
                  width: isToday && !isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(d).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white70
                          : AColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isToday ? AColors.primary : AColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── TASK LIST (local removal to satisfy Slidable dismiss lifecycle) ─────
class _TaskList extends StatefulWidget {
  final List<TaskModel> tasks;
  final Future<void> Function(TaskModel) onComplete;
  final Future<void> Function(TaskModel) onUndo;
  final Future<void> Function(TaskModel) onDelete;
  final Function(TaskModel) onTap;
  final Function(TaskModel) onLongPress;

  const _TaskList({
    required this.tasks,
    required this.onComplete,
    required this.onUndo,
    required this.onDelete,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<_TaskList> {
  late List<TaskModel> _visible;

  @override
  void initState() {
    super.initState();
    _visible = List<TaskModel>.from(widget.tasks);
  }

  @override
  void didUpdateWidget(covariant _TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visible = List<TaskModel>.from(widget.tasks);
  }

  void _removeLocalById(String id) {
    setState(() {
      _visible.removeWhere((t) => t.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_visible.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✅', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text('All clear!', style: AText.titleMedium),
            SizedBox(height: 6),
            Text('Nothing here.', style: AText.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _visible.length,
      itemBuilder: (_, i) {
        final task = _visible[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SwipeableTaskTile(
            key: ValueKey(task.id),
            task: task,
            onDismissComplete: () async {
              if (!task.done) {
                await widget.onComplete(task);
              } else {
                await widget.onUndo(task);
              }
            },
            onDismissDelete: () async {
              _removeLocalById(task.id);
              await widget.onDelete(task);
            },
            onCompleteTap: () => widget.onComplete(task),
            onUndoTap: () => widget.onUndo(task),
            onDeleteTap: () async {
              _removeLocalById(task.id);
              await widget.onDelete(task);
            },
            onTap: () => widget.onTap(task),
            onLongPress: () => widget.onLongPress(task),
          ),
        );
      },
    );
  }
}

// ─── SWIPEABLE TASK TILE ─────────────────────────────────────────────────
class _SwipeableTaskTile extends StatefulWidget {
  final TaskModel task;

  final Future<void> Function() onDismissComplete;
  final Future<void> Function() onDismissDelete;

  final Future<void> Function() onCompleteTap;
  final Future<void> Function() onUndoTap;
  final Future<void> Function() onDeleteTap;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SwipeableTaskTile({
    super.key,
    required this.task,
    required this.onDismissComplete,
    required this.onDismissDelete,
    required this.onCompleteTap,
    required this.onUndoTap,
    required this.onDeleteTap,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_SwipeableTaskTile> createState() => _SwipeableTaskTileState();
}

class _SwipeableTaskTileState extends State<_SwipeableTaskTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _strikeCtrl;
  late Animation<double> _strikeAnim;

  @override
  void initState() {
    super.initState();
    _strikeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _strikeAnim = CurvedAnimation(
      parent: _strikeCtrl,
      curve: Curves.easeOutCubic,
    );
    if (widget.task.done) _strikeCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _SwipeableTaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.done && !oldWidget.task.done) _strikeCtrl.forward();
    if (!widget.task.done && oldWidget.task.done) _strikeCtrl.reverse();
  }

  @override
  void dispose() {
    _strikeCtrl.dispose();
    super.dispose();
  }

  Color get _priorityColor {
    final p = widget.task.priority;
    if (p >= 8) return AColors.priority1;
    if (p >= 5) return AColors.priority2;
    if (p >= 3) return AColors.priority3;
    return AColors.priority4;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final hasSubs = task.subtasks.isNotEmpty;
    final subDone = task.subtasks.where((s) => s.done).length;
    final subProgress = hasSubs ? subDone / task.subtasks.length : 0.0;

    return Slidable(
      key: ValueKey(task.id),
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.30,
        dragDismissible: true,
        dismissible: DismissiblePane(
          closeOnCancel: true,
          dismissThreshold: 0.20, // smoother, shorter swipe
          onDismissed: () async {
            await widget.onDismissComplete();
          },
        ),
        children: [
          CustomSlidableAction(
            onPressed: (_) async {
              if (!task.done) {
                await widget.onCompleteTap();
              } else {
                await widget.onUndoTap();
              }
            },
            backgroundColor: task.done ? AColors.info : AColors.primary,
            borderRadius: ARadius.lg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  task.done ? Icons.refresh_rounded : Icons.check_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  task.done ? 'Undo' : 'Done',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.30,
        dragDismissible: true,
        dismissible: DismissiblePane(
          closeOnCancel: true,
          dismissThreshold: 0.20, // smoother, shorter swipe
          onDismissed: () async {
            await widget.onDismissDelete();
          },
        ),
        children: [
          CustomSlidableAction(
            onPressed: (_) async => widget.onDeleteTap(),
            backgroundColor: AColors.error,
            borderRadius: ARadius.lg,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                SizedBox(height: 4),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: task.done ? AColors.bgElevated : AColors.bgCard,
            borderRadius: ARadius.lg,
            border: Border.all(
              color: task.pending
                  ? AColors.warning.withValues(alpha: 0.5)
                  : (task.done
                  ? AColors.border.withValues(alpha: 0.5)
                  : AColors.border),
              width: task.pending ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 3,
                      height: hasSubs ? 58 : 40,
                      decoration: BoxDecoration(
                        color: task.done
                            ? AColors.textMuted.withValues(alpha: 0.3)
                            : (task.pending
                            ? AColors.warning
                            : _priorityColor),
                        borderRadius: ARadius.full,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.pending)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AColors.warning.withValues(alpha: 0.15),
                                borderRadius: ARadius.full,
                              ),
                              child: const Text(
                                'PENDING',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AColors.warning,
                                ),
                              ),
                            ),
                          AnimatedBuilder(
                            animation: _strikeAnim,
                            builder: (_, __) => Stack(
                              children: [
                                Text(
                                  task.title,
                                  style: AText.bodyLarge.copyWith(
                                    color: task.done
                                        ? AColors.textMuted
                                        : AColors.textPrimary,
                                  ),
                                ),
                                if (_strikeAnim.value > 0)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 11,
                                    child: FractionallySizedBox(
                                      widthFactor: _strikeAnim.value,
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        height: 1.5,
                                        color: AColors.textMuted.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              if (task.category.trim().isNotEmpty)
                                _MiniTag(
                                  label: task.category,
                                  color: AColors.primary,
                                ),
                              _MiniTag(
                                label: 'P${task.priority}',
                                color: _priorityColor,
                              ),
                              if (task.dueDate != null)
                                _MiniTag(
                                  label:
                                  DateFormat('MMM d').format(task.dueDate!),
                                  color: AColors.textMuted,
                                  icon: Icons.calendar_today_rounded,
                                ),
                              if (task.reminderTime != null)
                                _MiniTag(
                                  label: task.reminderTime!.format(context),
                                  color: AColors.info,
                                  icon: Icons.notifications_rounded,
                                ),
                              if (task.note != null &&
                                  task.note!.trim().isNotEmpty)
                                _MiniTag(
                                  label: 'Note',
                                  color: AColors.textMuted,
                                  icon: Icons.notes_rounded,
                                ),
                            ],
                          ),
                          if (hasSubs) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: ARadius.full,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: subProgress),
                                      duration:
                                      const Duration(milliseconds: 500),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, val, __) =>
                                          LinearProgressIndicator(
                                            value: val,
                                            backgroundColor: AColors.border,
                                            valueColor: AlwaysStoppedAnimation(
                                              subProgress == 1.0
                                                  ? AColors.primary
                                                  : _priorityColor,
                                            ),
                                            minHeight: 4,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$subDone/${task.subtasks.length}',
                                  style: AText.bodySmall.copyWith(
                                    color: _priorityColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hasSubs)
                      GestureDetector(
                        onTap: () {
                          setState(() => _expanded = !_expanded);
                          HapticFeedback.selectionClick();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () async {
                        task.done
                            ? await widget.onUndoTap()
                            : await widget.onCompleteTap();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: task.done
                              ? AColors.primary
                              : Colors.transparent,
                          borderRadius: ARadius.sm,
                          border: Border.all(
                            color: task.done
                                ? AColors.primary
                                : AColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: task.done
                            ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: _expanded && hasSubs
                    ? Column(
                  children: [
                    const Divider(height: 1, color: AColors.border),
                    ...task.subtasks.map(
                          (s) => _SubtaskRow(
                        subtask: s,
                        onToggle: () {
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SUBTASK ROW ──────────────────────────────────────────────────────────
class _SubtaskRow extends StatelessWidget {
  final SubTaskModel subtask;
  final VoidCallback onToggle;

  const _SubtaskRow({
    required this.subtask,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: subtask.done ? AColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: subtask.done ? AColors.primary : AColors.border,
                  width: 1.5,
                ),
              ),
              child: subtask.done
                  ? const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 12,
              )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtask.title,
                style: AText.bodyMedium.copyWith(
                  color: subtask.done
                      ? AColors.textMuted
                      : AColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SETTINGS SHEET ───────────────────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  final SortMode sortMode;
  final DisplayMode displayMode;
  final bool hideCompleted;
  final Function(SortMode) onSortChanged;
  final Function(DisplayMode) onDisplayChanged;
  final Function(bool) onHideChanged;

  const _SettingsSheet({
    required this.sortMode,
    required this.displayMode,
    required this.hideCompleted,
    required this.onSortChanged,
    required this.onDisplayChanged,
    required this.onHideChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const Text('Settings', style: AText.titleLarge),
          const SizedBox(height: 24),

          const Text('Sort by', style: AText.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              _SettingChip(
                label: '⏰  Date',
                selected: sortMode == SortMode.date,
                onTap: () {
                  onSortChanged(SortMode.date);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 10),
              _SettingChip(
                label: '🔺  Priority',
                selected: sortMode == SortMode.priority,
                onTap: () {
                  onSortChanged(SortMode.priority);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Display mode', style: AText.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              _SettingChip(
                label: '▦  Cards',
                selected: displayMode == DisplayMode.cards,
                onTap: () {
                  onDisplayChanged(DisplayMode.cards);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 10),
              _SettingChip(
                label: '📅  Calendar',
                selected: displayMode == DisplayMode.calendar,
                onTap: () {
                  onDisplayChanged(DisplayMode.calendar);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () {
              onHideChanged(!hideCompleted);
              HapticFeedback.lightImpact();
            },
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hide completed tasks', style: AText.bodyLarge),
                      Text('Only show active tasks', style: AText.bodySmall),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 50,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hideCompleted ? AColors.primary : AColors.bgCard,
                    borderRadius: ARadius.full,
                    border: Border.all(
                      color: hideCompleted
                          ? AColors.primary
                          : AColors.border,
                    ),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: hideCompleted
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AColors.primaryGlow : AColors.bgCard,
          borderRadius: ARadius.md,
          border: Border.all(
            color: selected ? AColors.primary : AColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AColors.primary : AColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── TASK EDITOR SHEET ────────────────────────────────────────────────────
class _TaskEditorSheet extends StatefulWidget {
  final TaskModel? existing;
  final List<String> categories;
  final String uid;

  const _TaskEditorSheet({
    this.existing,
    required this.categories,
    required this.uid,
  });

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _subtaskCtrl;

  late int _priority;
  String? _category;
  late bool _pending;

  DateTime? _dueDate;
  TimeOfDay? _reminderTime;
  List<int> _reminderDays = [];
  final List<SubTaskModel> _subtasks = [];
  final _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _subtaskCtrl = TextEditingController();

    _priority = e?.priority ?? 5;
    _category = (e?.category != null && e!.category.trim().isNotEmpty)
        ? e.category
        : null;
    _pending = e?.pending ?? false;
    _dueDate = e?.dueDate ?? DateTime.now();
    _reminderTime = e?.reminderTime;
    _reminderDays = List<int>.from(e?.reminderDays ?? []);
    _subtasks.addAll(
      (e?.subtasks ?? []).map(
            (s) => SubTaskModel(id: s.id, title: s.title, done: s.done),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
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

    if (p != null) {
      setState(() => _dueDate = p);
    }
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

    if (p != null) {
      setState(() => _reminderTime = p);
    }
  }

  void _addSubtask() {
    final value = _subtaskCtrl.text.trim();
    if (value.isEmpty) return;

    setState(() {
      _subtasks.add(
        SubTaskModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: value,
          done: false,
        ),
      );
      _subtaskCtrl.clear();
    });

    HapticFeedback.lightImpact();
  }

  void _toggleSubtask(int index) {
    final s = _subtasks[index];
    setState(() {
      _subtasks[index] = SubTaskModel(
        id: s.id,
        title: s.title,
        done: !s.done,
      );
    });
    HapticFeedback.selectionClick();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (title.isEmpty) return;

    HapticFeedback.mediumImpact();

    Navigator.pop(
      context,
      TaskModel(
        id: widget.existing?.id ?? '',
        uid: widget.existing?.uid.isNotEmpty == true
            ? widget.existing!.uid
            : widget.uid,
        title: title,
        note: note.isEmpty ? null : note,
        done: widget.existing?.done ?? false,
        pending: _pending,
        priority: _priority,
        category: _category?.trim() ?? '',
        dueDate: _dueDate,
        reminderTime: _reminderTime,
        reminderDays: _reminderDays,
        subtasks: List<SubTaskModel>.from(_subtasks),
        xpSphere: widget.existing?.xpSphere ?? XpSphere.willpower,
        xpReward: widget.existing?.xpReward ?? 10,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      widget.existing == null ? 'New Task' : 'Edit Task',
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
                    TextField(
                      controller: _titleCtrl,
                      autofocus: widget.existing == null,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AColors.textPrimary,
                      ),
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'What needs to be done?',
                        hintStyle: TextStyle(
                          color: AColors.textMuted,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                      ),
                    ),
                    const Divider(color: AColors.border),
                    const SizedBox(height: 16),

                    _Sec(
                      label: 'Note',
                      icon: Icons.notes_rounded,
                      child: TextField(
                        controller: _noteCtrl,
                        style: AText.bodyMedium,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Add a note...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Priority  •  $_priority / 10',
                      icon: Icons.flag_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _pColor(_priority),
                              thumbColor: _pColor(_priority),
                              inactiveTrackColor: AColors.border,
                              overlayColor:
                              _pColor(_priority).withValues(alpha: 0.15),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 11,
                              ),
                            ),
                            child: Slider(
                              value: _priority.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              onChanged: (v) {
                                setState(() => _priority = v.round());
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: ['Low', 'Medium', 'High', 'Urgent']
                                  .map((l) => Text(l, style: AText.bodySmall))
                                  .toList(),
                            ),
                          ),
                        ],
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
                                setState(() => _category = c);
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
                                  color: sel
                                      ? AColors.primaryGlow
                                      : AColors.bgCard,
                                  borderRadius: ARadius.full,
                                  border: Border.all(
                                    color: sel
                                        ? AColors.primary
                                        : AColors.border,
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? AColors.primary
                                        : AColors.textMuted,
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

                    _Sec(
                      label: 'Due Date',
                      icon: Icons.calendar_month_rounded,
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: _dueDate != null
                                ? AColors.primaryGlow
                                : AColors.bgCard,
                            borderRadius: ARadius.md,
                            border: Border.all(
                              color: _dueDate != null
                                  ? AColors.primary
                                  : AColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: _dueDate != null
                                    ? AColors.primary
                                    : AColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _dueDate != null
                                    ? DateFormat('EEE, MMM d yyyy')
                                    .format(_dueDate!)
                                    : 'Choose a date',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dueDate != null
                                      ? AColors.primary
                                      : AColors.textMuted,
                                ),
                              ),
                              const Spacer(),
                              if (_dueDate != null)
                                GestureDetector(
                                  onTap: () => setState(() => _dueDate = null),
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
                      label: 'Reminder',
                      icon: Icons.notifications_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
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
                                        : 'Set reminder time',
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
                                      onTap: () => setState(() {
                                        _reminderTime = null;
                                        _reminderDays = [];
                                      }),
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
                          if (_reminderTime != null) ...[
                            const SizedBox(height: 12),
                            const Text('Repeat on days', style: AText.bodyMedium),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (i) {
                                final day = i + 1;
                                final sel = _reminderDays.contains(day);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (sel) {
                                        _reminderDays.remove(day);
                                      } else {
                                        _reminderDays.add(day);
                                      }
                                    });
                                    HapticFeedback.selectionClick();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AColors.primary
                                          : AColors.bgCard,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: sel
                                            ? AColors.primary
                                            : AColors.border,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _dayLabels[i],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: sel
                                              ? Colors.white
                                              : AColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _reminderDays.isEmpty
                                  ? 'One-time on due date'
                                  : 'Repeats on selected days',
                              style: AText.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Sec(
                      label: 'Subtasks',
                      icon: Icons.checklist_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._subtasks.asMap().entries.map(
                                (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleSubtask(entry.key),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: entry.value.done
                                            ? AColors.primary
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: entry.value.done
                                              ? AColors.primary
                                              : AColors.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: entry.value.done
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
                                      entry.value.title,
                                      style: AText.bodyMedium.copyWith(
                                        color: entry.value.done
                                            ? AColors.textMuted
                                            : AColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(
                                            () => _subtasks.removeAt(entry.key),
                                      );
                                    },
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
                                  controller: _subtaskCtrl,
                                  style: AText.bodyMedium,
                                  onSubmitted: (_) => _addSubtask(),
                                  decoration: const InputDecoration(
                                    hintText: 'Add a subtask...',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _addSubtask,
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
                      label: 'Options',
                      icon: Icons.tune_rounded,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _pending = !_pending);
                          HapticFeedback.lightImpact();
                        },
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Mark as Pending', style: AText.bodyLarge),
                                  Text(
                                    'Task is blocked or waiting',
                                    style: AText.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: 50,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _pending
                                    ? AColors.warning
                                    : AColors.bgCard,
                                borderRadius: ARadius.full,
                                border: Border.all(
                                  color: _pending
                                      ? AColors.warning
                                      : AColors.border,
                                ),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                alignment: _pending
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
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
                          ],
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

Color _pColor(int p) {
  if (p >= 8) return AColors.priority1;
  if (p >= 5) return AColors.priority2;
  if (p >= 3) return AColors.priority3;
  return AColors.priority4;
}

// ─── HELPERS ──────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AText.labelLarge.copyWith(
                color: AColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
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
  Widget build(BuildContext context) {
    return GestureDetector(
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
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool gradient;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: gradient ? AColors.gradientPrimary : null,
          color: gradient ? null : AColors.bgCard,
          borderRadius: ARadius.md,
          border: gradient ? null : Border.all(color: AColors.border),
          boxShadow: gradient
              ? [
            BoxShadow(
              color: AColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Icon(
          icon,
          color: gradient ? Colors.white : AColors.textPrimary,
          size: 22,
        ),
      ),
    );
  }
}