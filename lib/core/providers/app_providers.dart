import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../providers/notification_log_provider.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

// ─── SETTINGS & THEME ──────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize SharedPreferences Provider in main.dart');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(sharedPreferencesProvider));
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  final SettingsService _service;
  ThemeModeNotifier(this._service) : super(_service.getThemeMode());

  Future<void> setMode(AppThemeMode mode) async {
    await _service.setThemeMode(mode);
    state = mode;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(settingsServiceProvider));
});

class ColorThemeNotifier extends StateNotifier<AppColorTheme> {
  final SettingsService _service;
  ColorThemeNotifier(this._service) : super(_service.getColorTheme());

  Future<void> setTheme(AppColorTheme theme) async {
    await _service.setColorTheme(theme);
    state = theme;
  }
}

final colorThemeProvider = StateNotifierProvider<ColorThemeNotifier, AppColorTheme>((ref) {
  return ColorThemeNotifier(ref.watch(settingsServiceProvider));
});

// ─── AUTH ──────────────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) =>
    FirebaseAuth.instance.authStateChanges());

final currentUidProvider = Provider<String?>((ref) =>
ref.watch(authStateProvider).valueOrNull?.uid);

// ─── XP EVENT SYSTEM ───────────────────────────────────────────────────────
class XpEvent {
  final XpSphere sphere;
  final int amount;
  final bool isLevelUp;
  final int newLevel;

  const XpEvent({
    required this.sphere,
    required this.amount,
    this.isLevelUp = false,
    this.newLevel = 0,
  });
}

final xpEventProvider = StateProvider<XpEvent?>((ref) => null);

// ─── USER PROFILE ──────────────────────────────────────────────────────────
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return UserRepository.stream(uid);
});

class UserNotifier extends AsyncNotifier<void> {
  @override Future<void> build() async {}

  Future<void> addCustomCategory(String category) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return Future.value();
    return UserRepository.addCustomCategory(uid, category);
  }
}

final userActionsProvider = AsyncNotifierProvider<UserNotifier, void>(UserNotifier.new);

// ─── GLOBAL CATEGORIES ───────────────────────────────────────────────────
final allCategoriesProvider = Provider<List<String>>((ref) {
  final base = {'Personal', 'Work', 'Health', 'Finance', 'Errands', 'Social', 'Mind', 'Fitness', 'Career', 'Learning'};

  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile != null) {
    base.addAll(profile.customCategories);
  }

  final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
  for (var t in tasks) {
    if (t.category.isNotEmpty) base.add(t.category);
  }

  final habits = ref.watch(habitsProvider).valueOrNull ?? [];
  for (var h in habits) {
    if (h.category.isNotEmpty) base.add(h.category);
  }

  final goals = ref.watch(goalsProvider).valueOrNull ?? [];
  for (var g in goals) {
    if (g.category.isNotEmpty) base.add(g.category);
  }

  final sorted = base.toList();
  sorted.sort();
  return sorted;
});

// ─── TASKS ─────────────────────────────────────────────────────────────────
final tasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return TaskRepository.stream(uid);
});

// Derived: today's tasks
final todayTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
  final today = DateTime.now();
  return tasks.where((t) =>
  t.dueDate != null &&
      t.dueDate!.year == today.year &&
      t.dueDate!.month == today.month &&
      t.dueDate!.day == today.day
  ).toList();
});

// Derived: upcoming tasks
final upcomingTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  return tasks.where((t) =>
  t.dueDate != null && t.dueDate!.isAfter(todayStart) &&
      !(t.dueDate!.year == today.year &&
          t.dueDate!.month == today.month &&
          t.dueDate!.day == today.day)
  ).toList();
});

// ─── HABITS ────────────────────────────────────────────────────────────────
final habitsProvider = StreamProvider<List<HabitModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return HabitRepository.stream(uid);
});

// Derived: today's habits (non-archived, scheduled for today)
final todayHabitsProvider = Provider<List<HabitModel>>((ref) {
  final habits = ref.watch(habitsProvider).valueOrNull ?? [];
  final weekday = DateTime.now().weekday; // 1=Mon..7=Sun
  return habits.where((h) {
    if (h.archived) return false;
    if (h.isExpired) return false; // duration-limited habit has ended
    if (h.scheduleDays.isEmpty) return true; // daily
    return h.scheduleDays.contains(weekday);
  }).toList();
});

// Derived: today completion rate
final todayHabitRateProvider = Provider<double>((ref) {
  final habits = ref.watch(todayHabitsProvider);
  if (habits.isEmpty) return 0.0;
  final done = habits.where((h) => h.isCompletedToday).length;
  return done / habits.length;
});

// ─── GOALS ─────────────────────────────────────────────────────────────────
final goalsProvider = StreamProvider<List<GoalModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return GoalRepository.stream(uid);
});

final activeGoalsProvider = Provider<List<GoalModel>>((ref) =>
    (ref.watch(goalsProvider).valueOrNull ?? [])
        .where((g) => !g.archived && !g.isComplete).toList());

final completedGoalsProvider = Provider<List<GoalModel>>((ref) =>
    (ref.watch(goalsProvider).valueOrNull ?? [])
        .where((g) => g.isComplete).toList());

// ─── POMODORO ──────────────────────────────────────────────────────────────
final pomodoroSessionsProvider = StreamProvider<List<PomodoroSession>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return PomodoroRepository.streamRecent(uid);
});

// Derived: today's focus minutes
final todayFocusMinutesProvider = Provider<int>((ref) {
  final sessions = ref.watch(pomodoroSessionsProvider).valueOrNull ?? [];
  final today = DateTime.now();
  return sessions
      .where((s) =>
  s.date.year == today.year &&
      s.date.month == today.month &&
      s.date.day == today.day)
      .fold(0, (sum, s) => sum + s.durationMinutes);
});

// Derived: this week's focus minutes per day [M..S]
final weekFocusMinutesProvider = Provider<List<int>>((ref) {
  final sessions = ref.watch(pomodoroSessionsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  // Find this week's Monday
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return List.generate(7, (i) {
    final day = monday.add(Duration(days: i));
    return sessions
        .where((s) =>
    s.date.year == day.year &&
        s.date.month == day.month &&
        s.date.day == day.day)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  });
});

// ─── LIFE BALANCE ──────────────────────────────────────────────────────────
final lifeBalanceProvider = StreamProvider<List<LifeBalanceSnapshot>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return LifeBalanceRepository.stream(uid);
});

final latestBalanceProvider = Provider<LifeBalanceSnapshot?>((ref) {
  final snaps = ref.watch(lifeBalanceProvider).valueOrNull ?? [];
  if (snaps.isEmpty) return null;
  // Explicitly pick newest by date — don't rely on stream sort order
  return snaps.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
});

// ─── TASK ACTIONS ──────────────────────────────────────────────────────────
class TaskNotifier extends AsyncNotifier<void> {
  @override Future<void> build() async {}

  String get _uid => ref.read(currentUidProvider)!;

  Future<void> create(TaskModel task) async {
    await TaskRepository.create(_uid,
      title: task.title, note: task.note,
      priority: task.priority, category: task.category,
      dueDate: task.dueDate,
      reminderTime: task.reminderTime,
      reminderDays: task.reminderDays,
      subtasks: task.subtasks,
      pending: task.pending,
      xpSphere: task.xpSphere,
      xpReward: task.xpReward,
    );
    // Schedule reminder if set
    await NotificationService.instance.scheduleTaskReminder(task);
  }

  Future<void> save(TaskModel task) async {
    await TaskRepository.update(_uid, task);
    // Re-schedule in case time/days changed
    await NotificationService.instance.scheduleTaskReminder(task);
  }

  Future<void> delete(String id) async {
    await TaskRepository.delete(_uid, id);
    await NotificationService.instance.cancelTask(id);
    // Remove from notification center too
    await ref.read(notificationLogProvider.notifier).remove('task-$id');
  }

  Future<void> setDone(TaskModel task, bool done) async {
    if (done) {
      // Completing: award XP only if not already awarded for this task
      await TaskRepository.setDone(_uid, task.id, true, xpAwarded: true);
      await NotificationService.instance.cancelTask(task.id);
      await ref.read(notificationLogProvider.notifier).remove('task-${task.id}');

      if (!task.xpAwarded) {
        final profileBefore = ref.read(userProfileProvider).valueOrNull;
        final levelBefore = profileBefore?.levelForSphere(task.xpSphere) ?? 1;
        await UserRepository.addXp(_uid, task.xpSphere, task.xpReward);
        final profileAfter = await UserRepository.get(_uid);
        final levelAfter = profileAfter?.levelForSphere(task.xpSphere) ?? levelBefore;
        ref.read(xpEventProvider.notifier).state = XpEvent(
          sphere: task.xpSphere,
          amount: task.xpReward,
          isLevelUp: levelAfter > levelBefore,
          newLevel: levelAfter,
        );
      }
    } else {
      // Undoing: clear done + xpAwarded, and deduct XP if it was previously awarded
      await TaskRepository.setDone(_uid, task.id, false, xpAwarded: false);
      await NotificationService.instance.scheduleTaskReminder(task);

      if (task.xpAwarded) {
        await UserRepository.subtractXp(_uid, task.xpSphere, task.xpReward);
      }
    }
  }
}

final taskActionsProvider = AsyncNotifierProvider<TaskNotifier, void>(TaskNotifier.new);

// ─── HABIT ACTIONS ─────────────────────────────────────────────────────────
class HabitNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _uid => ref.read(currentUidProvider)!;

  Future<HabitModel> create({
    required String name,
    String emoji = '⭐',
    String category = 'Personal',
    int colorValue = 0xFF00C97B,
    List<int> scheduleDays = const [],
    XpSphere? xpSphere,
    int xpReward = 15,
    String? note,
    TimeOfDay? reminderTime,
    bool isUnlimited = true,
    int? durationDays,
  }) async {
    final habit = await HabitRepository.create(
      _uid,
      name: name,
      emoji: emoji,
      category: category,
      colorValue: colorValue,
      scheduleDays: scheduleDays,
      xpSphere: xpSphere,
      xpReward: xpReward,
      note: note,
      reminderTime: reminderTime,
      isUnlimited: isUnlimited,
      durationDays: durationDays,
    );
    await NotificationService.instance.scheduleHabitReminder(habit);
    return habit;
  }

  Future<void> save(HabitModel habit) async {
    await HabitRepository.update(_uid, habit);
    await NotificationService.instance.scheduleHabitReminder(habit);
  }

  Future<void> delete(String id) async {
    await HabitRepository.delete(_uid, id);
    await NotificationService.instance.cancelHabit(id);
    await ref.read(notificationLogProvider.notifier).remove('habit-$id');
  }

  Future<void> toggleToday(HabitModel habit) async {
    final wasComplete = habit.isCompletedToday;
    final updated = await HabitRepository.toggleToday(_uid, habit);
    final nowComplete = updated.isCompletedToday;

    if (!wasComplete && nowComplete) {
      // Habit just completed for today — award XP
      await ref.read(notificationLogProvider.notifier).remove('habit-${habit.id}');
      final profileBefore = ref.read(userProfileProvider).valueOrNull;
      final levelBefore = profileBefore?.levelForSphere(habit.xpSphere) ?? 1;
      await UserRepository.addXp(_uid, habit.xpSphere, habit.xpReward);
      final profileAfter = await UserRepository.get(_uid);
      final levelAfter = profileAfter?.levelForSphere(habit.xpSphere) ?? levelBefore;
      ref.read(xpEventProvider.notifier).state = XpEvent(
        sphere: habit.xpSphere,
        amount: habit.xpReward,
        isLevelUp: levelAfter > levelBefore,
        newLevel: levelAfter,
      );
    } else if (wasComplete && !nowComplete) {
      // Habit un-toggled — deduct the XP that was awarded
      await UserRepository.subtractXp(_uid, habit.xpSphere, habit.xpReward);
    }
  }
}

final habitActionsProvider =
AsyncNotifierProvider<HabitNotifier, void>(HabitNotifier.new);

// ─── GOAL ACTIONS ──────────────────────────────────────────────────────────
class GoalNotifier extends AsyncNotifier<void> {
  @override Future<void> build() async {}

  String get _uid => ref.read(currentUidProvider)!;

  Future<void> create(GoalModel goal) async {
    await GoalRepository.create(_uid,
        title: goal.title, category: goal.category, emoji: goal.emoji,
        colorValue: goal.colorValue, note: goal.note, deadline: goal.deadline,
        steps: goal.steps, xpSphere: goal.xpSphere, xpReward: goal.xpReward,
        customReward: goal.customReward, measureTarget: goal.measureTarget,
        measureUnit: goal.measureUnit);
    await NotificationService.instance.scheduleGoalDeadline(goal);
  }

  Future<void> save(GoalModel goal) async {
    await GoalRepository.update(_uid, goal);
    await NotificationService.instance.scheduleGoalDeadline(goal);
  }

  Future<void> delete(String id) async {
    await GoalRepository.delete(_uid, id);
    await NotificationService.instance.cancelGoal(id);
  }

  Future<void> markComplete(GoalModel goal) async {
    final xp = goal.computedXpReward;
    final updated = goal.copyWith(manuallyComplete: true, xpReward: xp);
    await GoalRepository.update(_uid, updated);
    await NotificationService.instance.cancelGoal(goal.id);
    final profileBefore = ref.read(userProfileProvider).valueOrNull;
    final levelBefore = profileBefore?.levelForSphere(goal.xpSphere) ?? 1;
    await UserRepository.addXp(_uid, goal.xpSphere, xp);
    final profileAfter = await UserRepository.get(_uid);
    final levelAfter = profileAfter?.levelForSphere(goal.xpSphere) ?? levelBefore;
    ref.read(xpEventProvider.notifier).state = XpEvent(
      sphere: goal.xpSphere,
      amount: xp,
      isLevelUp: levelAfter > levelBefore,
      newLevel: levelAfter,
    );
  }

  /// Add a check-in journal entry. If delta is provided and the goal is measurable,
  /// also advances measureCurrent. Returns true if this check-in completed the goal.
  Future<bool> addCheckIn(GoalModel goal, String note, double? delta) async {
    final checkIn = GoalCheckInModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      note: note,
      date: DateTime.now(),
      progressDelta: delta,
    );

    double newCurrent = goal.measureCurrent;
    if (delta != null && goal.measureTarget != null) {
      newCurrent = (goal.measureCurrent + delta).clamp(0.0, goal.measureTarget! * 10);
    }

    final updated = goal.copyWith(
      checkIns: [...goal.checkIns, checkIn],
      measureCurrent: newCurrent,
    );
    await GoalRepository.update(_uid, updated);

    // Auto-complete if measurable goal just hit 100%
    if (!goal.isComplete && updated.isComplete) {
      await markComplete(updated);
      return true;
    }
    return false;
  }

  /// Directly set measureCurrent value (e.g., absolute entry mode).
  Future<bool> logMeasureProgress(GoalModel goal, double newValue) async {
    final updated = goal.copyWith(measureCurrent: newValue.clamp(0.0, double.infinity));
    await GoalRepository.update(_uid, updated);
    if (!goal.isComplete && updated.isComplete) {
      await markComplete(updated);
      return true;
    }
    return false;
  }
}

final goalActionsProvider = AsyncNotifierProvider<GoalNotifier, void>(GoalNotifier.new);


// ─── POMODORO ACTIONS ──────────────────────────────────────────────────────
class PomodoroNotifier extends AsyncNotifier<void> {
  @override Future<void> build() async {}

  String get _uid => ref.read(currentUidProvider)!;

  Future<void> logSession({
    required int durationMinutes,
    String? linkedTaskId,
    String? linkedTaskTitle,
  }) async {
    await PomodoroRepository.logSession(_uid,
        durationMinutes: durationMinutes,
        linkedTaskId: linkedTaskId,
        linkedTaskTitle: linkedTaskTitle);
    // Pomodoro gives Willpower XP: minutes ÷ 5 (min 1 XP)
    final xpAmount = (durationMinutes ~/ 5).clamp(1, 999);
    final profileBefore = ref.read(userProfileProvider).valueOrNull;
    final levelBefore = profileBefore?.levelForSphere(XpSphere.willpower) ?? 1;
    await UserRepository.addXp(_uid, XpSphere.willpower, xpAmount);
    final profileAfter = await UserRepository.get(_uid);
    final levelAfter = profileAfter?.levelForSphere(XpSphere.willpower) ?? levelBefore;
    ref.read(xpEventProvider.notifier).state = XpEvent(
      sphere: XpSphere.willpower,
      amount: xpAmount,
      isLevelUp: levelAfter > levelBefore,
      newLevel: levelAfter,
    );
  }
}



final pomodoroActionsProvider = AsyncNotifierProvider<PomodoroNotifier, void>(PomodoroNotifier.new);

// ─── LIFE BALANCE ACTIONS ──────────────────────────────────────────────────
class LifeBalanceNotifier extends AsyncNotifier<void> {
  @override Future<void> build() async {}

  Future<void> saveSnapshot(Map<String, double> scores) =>
      LifeBalanceRepository.saveSnapshot(ref.read(currentUidProvider)!, scores);
}

final lifeBalanceActionsProvider =
AsyncNotifierProvider<LifeBalanceNotifier, void>(LifeBalanceNotifier.new);

// ─── NOTIFICATION BOOT PROVIDER ────────────────────────────────────────────
// Watches tasks/habits/goals and re-registers all notifications once loaded.
// This restores alarms after app restarts (flutter_local_notifications only
// persists schedules while the app remembers them; this provider rebuilds them
// from Firestore on every cold start).
final notificationBootProvider = Provider<void>((ref) {
  final tasks  = ref.watch(tasksProvider).valueOrNull;
  final habits = ref.watch(habitsProvider).valueOrNull;
  final goals  = ref.watch(goalsProvider).valueOrNull;

  // Only reschedule once all 3 streams have data
  if (tasks == null || habits == null || goals == null) return;

  NotificationService.instance.rescheduleAll(
    tasks:  tasks,
    habits: habits,
    goals:  goals,
  );
});