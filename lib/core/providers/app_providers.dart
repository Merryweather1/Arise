import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import 'package:flutter/material.dart';

// ─── AUTH ──────────────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) =>
    FirebaseAuth.instance.authStateChanges());

final currentUidProvider = Provider<String?>((ref) =>
ref.watch(authStateProvider).valueOrNull?.uid);

// ─── USER PROFILE ──────────────────────────────────────────────────────────
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return UserRepository.stream(uid);
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
  return snaps.isEmpty ? null : snaps.first;
});

// ─── TASK ACTIONS ──────────────────────────────────────────────────────────
class TaskNotifier extends AsyncNotifier<void> {
  @override Future<void> build() async {}

  String get _uid => ref.read(currentUidProvider)!;

  Future<void> create(TaskModel task) async {
    await TaskRepository.create(_uid,
      title: task.title, note: task.note,
      priority: task.priority, category: task.category,
      dueDate: task.dueDate, subtasks: task.subtasks,
      xpSphere: task.xpSphere, xpReward: task.xpReward,
    );
  }

  Future<void> save(TaskModel task) =>
      TaskRepository.update(_uid, task);

  Future<void> delete(String id) =>
      TaskRepository.delete(_uid, id);

  Future<void> setDone(TaskModel task, bool done) async {
    await TaskRepository.setDone(_uid, task.id, done);
    // Award XP on completion
    if (done) await UserRepository.addXp(_uid, task.xpSphere, task.xpReward);
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
    XpSphere xpSphere = XpSphere.willpower,
    int xpReward = 15,
    String? note,
    TimeOfDay? reminderTime,
    bool isUnlimited = true,
    int? durationDays,
  }) =>
      HabitRepository.create(
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

  Future<void> save(HabitModel habit) =>
      HabitRepository.update(_uid, habit);

  Future<void> delete(String id) =>
      HabitRepository.delete(_uid, id);

  Future<void> toggleToday(HabitModel habit) async {
    final wasComplete = habit.isCompletedToday;
    final updated = await HabitRepository.toggleToday(_uid, habit);

    if (!wasComplete && updated.isCompletedToday) {
      await UserRepository.addXp(_uid, habit.xpSphere, habit.xpReward);
    }
  }
}

final habitActionsProvider =
AsyncNotifierProvider<HabitNotifier, void>(HabitNotifier.new);

// ─── GOAL ACTIONS ──────────────────────────────────────────────────────────
class GoalNotifier extends AsyncNotifier<void> {
  @override Future<void> build() async {}

  String get _uid => ref.read(currentUidProvider)!;

  Future<void> create(GoalModel goal) => GoalRepository.create(_uid,
      title: goal.title, category: goal.category, emoji: goal.emoji,
      colorValue: goal.colorValue, note: goal.note, deadline: goal.deadline,
      steps: goal.steps, xpSphere: goal.xpSphere, xpReward: goal.xpReward,
      customReward: goal.customReward, measureTarget: goal.measureTarget,
      measureUnit: goal.measureUnit);

  Future<void> save(GoalModel goal) =>
      GoalRepository.update(_uid, goal);

  Future<void> delete(String id) =>
      GoalRepository.delete(_uid, id);

  Future<void> markComplete(GoalModel goal) async {
    final updated = goal.copyWith(manuallyComplete: true);
    await GoalRepository.update(_uid, updated);
    await UserRepository.addXp(_uid, goal.xpSphere, goal.xpReward);
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
    // Pomodoro gives Willpower XP
    await UserRepository.addXp(_uid, XpSphere.willpower, durationMinutes ~/ 5);
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