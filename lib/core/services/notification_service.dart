import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_models.dart';

// ─── NOTIFICATION SERVICE ──────────────────────────────────────────────────
// Singleton that wraps flutter_local_notifications.
// Notification ID allocation:
//   Tasks:  abs(taskId.hashCode)  % 100000           (0–99999)
//   Habits: abs(habitId.hashCode) % 100000 + 100000  (100000–199999)
//   Goals:  abs(goalId.hashCode)  % 100000 + 200000  (200000–299999)
// Each task/habit gets up to 7 slots (one per weekday).

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Init ────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Init timezone database and point tz.local at the device's timezone
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    // Create the notification channel for reminders
    const channel = AndroidNotificationChannel(
      'arise_reminders',
      'Arise Reminders',
      description: 'Task, habit, and goal reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── ID helpers ──────────────────────────────────────────────────────────
  int _taskBaseId(String taskId) => taskId.hashCode.abs() % 100000;
  int _habitBaseId(String habitId) => habitId.hashCode.abs() % 100000 + 100000;
  int _goalId(String goalId) => goalId.hashCode.abs() % 100000 + 200000;

  // ── Notification details ─────────────────────────────────────────────────
  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'arise_reminders',
      'Arise Reminders',
      channelDescription: 'Task, habit, and goal reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
  );

  // ── Schedule helpers ─────────────────────────────────────────────────────

  /// Converts a Day-of-week int (1=Mon..7=Sun) to [Day] enum — kept for
  /// potential future use (weekly narrowing by Day enum).
  // ignore: unused_element
  Day _toDay(int d) => const {
        1: Day.monday,
        2: Day.tuesday,
        3: Day.wednesday,
        4: Day.thursday,
        5: Day.friday,
        6: Day.saturday,
        7: Day.sunday,
      }[d]!;

  /// Returns a [tz.TZDateTime] for the next occurrence of [weekday] at [time].
  tz.TZDateTime _nextWeekday(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    // Walk forward until we hit the right weekday
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── TASK REMINDERS ──────────────────────────────────────────────────────

  /// Schedules (or reschedules) all weekday reminders for a task.
  /// If the task has no reminderTime or is completed, just cancels instead.
  Future<void> scheduleTaskReminder(TaskModel task) async {
    await cancelTask(task.id);
    if (task.done || task.reminderTime == null) return;

    final days = task.reminderDays.isEmpty
        ? List.generate(7, (i) => i + 1) // Mon–Sun
        : task.reminderDays;

    for (final weekday in days) {
      final id = _taskBaseId(task.id) + (weekday - 1);
      await _plugin.zonedSchedule(
        id,
        '📋 ${task.title}',
        task.note?.isNotEmpty == true ? task.note! : 'Tap to open your task',
        _nextWeekday(weekday, task.reminderTime!),
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'task:${task.id}',
      );
    }
  }

  /// Cancels all reminder slots for a task (up to 7 weekday slots).
  Future<void> cancelTask(String taskId) async {
    final base = _taskBaseId(taskId);
    for (var i = 0; i < 7; i++) {
      await _plugin.cancel(base + i);
    }
  }

  // ── HABIT REMINDERS ─────────────────────────────────────────────────────

  /// Schedules (or reschedules) a weekly repeating reminder for each habit day.
  Future<void> scheduleHabitReminder(HabitModel habit) async {
    await cancelHabit(habit.id);
    if (habit.archived || habit.reminderTime == null) return;

    final days = habit.scheduleDays.isEmpty
        ? List.generate(7, (i) => i + 1) // every day
        : habit.scheduleDays;

    for (final weekday in days) {
      final id = _habitBaseId(habit.id) + (weekday - 1);
      await _plugin.zonedSchedule(
        id,
        '${habit.emoji} ${habit.name}',
        'Time to complete your habit!',
        _nextWeekday(weekday, habit.reminderTime!),
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'habit:${habit.id}',
      );
    }
  }

  /// Cancels all reminder slots for a habit (up to 7 weekday slots).
  Future<void> cancelHabit(String habitId) async {
    final base = _habitBaseId(habitId);
    for (var i = 0; i < 7; i++) {
      await _plugin.cancel(base + i);
    }
  }

  // ── GOAL DEADLINE REMINDERS ─────────────────────────────────────────────

  /// Schedules a one-shot notification at 9 AM the morning before the deadline.
  Future<void> scheduleGoalDeadline(GoalModel goal) async {
    await cancelGoal(goal.id);
    if (goal.isComplete || goal.archived || goal.deadline == null) return;

    final deadline = goal.deadline!;
    final reminderDay = deadline.subtract(const Duration(days: 1));

    // Schedule for 9 AM the day before
    final scheduled = tz.TZDateTime(
      tz.local,
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      9,
      0,
    );

    // Only schedule future notifications
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _goalId(goal.id),
      '🎯 ${goal.title}',
      'Deadline is tomorrow! ${goal.isComplete ? 'Great job!' : 'Keep pushing!'}',
      scheduled,
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'goal:${goal.id}',
    );
  }

  /// Cancels the goal deadline notification.
  Future<void> cancelGoal(String goalId) async {
    await _plugin.cancel(_goalId(goalId));
  }

  // ── RESCHEDULE ALL (boot restore) ────────────────────────────────────────

  /// Re-registers all notifications. Call this on app startup.
  Future<void> rescheduleAll({
    required List<TaskModel> tasks,
    required List<HabitModel> habits,
    required List<GoalModel> goals,
  }) async {
    await _plugin.cancelAll();

    for (final task in tasks) {
      if (!task.done) await scheduleTaskReminder(task);
    }
    for (final habit in habits) {
      if (!habit.archived && !habit.isExpired) await scheduleHabitReminder(habit);
    }
    for (final goal in goals) {
      if (!goal.isComplete && !goal.archived) await scheduleGoalDeadline(goal);
    }
  }
}
