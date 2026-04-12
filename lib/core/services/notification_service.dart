import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_models.dart';
import '../providers/notification_log_provider.dart';

// в”Ђв”Ђв”Ђ NOTIFICATION SERVICE в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// ID allocation:
//   Tasks (one-shot):  abs(taskId.hashCode) % 100000          (0вЂ“99999)
//   Tasks (recurring, per weekday slot 0вЂ“6): base + weekday
//   Habits (per weekday slot 0вЂ“6): abs(habitId.hashCode) % 100000 + 100000
//   Goals (one-shot):  abs(goalId.hashCode) % 100000 + 200000

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  ProviderContainer? _container;

  // в”Ђв”Ђ Init в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  Future<void> initialize({ProviderContainer? container}) async {
    if (_initialized) return;
    _initialized = true;
    _container = container;

    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _plugin.initialize(const InitializationSettings(android: android));

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

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // в”Ђв”Ђ ID helpers в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  int _taskBaseId(String id) => id.hashCode.abs() % 100000;
  int _habitBaseId(String id) => id.hashCode.abs() % 100000 + 100000;
  int _goalId(String id)      => id.hashCode.abs() % 100000 + 200000;

  // в”Ђв”Ђ Notification details в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'arise_reminders',
      'Arise Reminders',
      channelDescription: 'Task, habit, and goal reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    ),
  );

  // в”Ђв”Ђ Helpers в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  /// Next occurrence of a specific [weekday] at [time] (used for habits only).
  tz.TZDateTime _nextWeekday(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var dt = tz.TZDateTime(tz.local, now.year, now.month, now.day,
        time.hour, time.minute);
    while (dt.weekday != weekday || dt.isBefore(now)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  /// Next occurrence of [time] today (or tomorrow if time has already passed).
  tz.TZDateTime _nextOccurrenceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var dt = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  // в”Ђв”Ђ TASK REMINDERS в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  //
  // Tasks are NOT repeating by default. A task reminder fires:
  //   вЂў Once, at [reminderTime] on the due date  (if dueDate is set)
  //   вЂў Once, at the next occurrence of [reminderTime]  (if no dueDate and no reminderDays)
  //   вЂў Repeating weekly on [reminderDays] at [reminderTime]  (if reminderDays is set вЂ” rare)
  //
  Future<void> scheduleTaskReminder(TaskModel task) async {
    await cancelTask(task.id);
    if (task.done || task.reminderTime == null) return;

    final body =
    task.note?.isNotEmpty == true ? task.note! : 'Tap to open your task';

    if (task.reminderDays.isNotEmpty) {
      // в”Ђв”Ђ Recurring task: fire every selected weekday в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
      tz.TZDateTime? earliest;
      for (final weekday in task.reminderDays) {
        final id = _taskBaseId(task.id) + weekday; // weekday 1вЂ“7 в†’ id + 1вЂ“7
        final when = _nextWeekday(weekday, task.reminderTime!);
        await _plugin.zonedSchedule(
          id,
          'рџ“‹ ${task.title}',
          body,
          when,
          _notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'task:${task.id}',
        );
        if (earliest == null || when.isBefore(earliest)) earliest = when;
      }
      // Log only the SOONEST upcoming fire time
      if (earliest != null) {
        _log(
          id: 'task-${task.id}',
          type: NotifType.task,
          title: task.title,
          body: body,
          time: earliest.toLocal(),
        );
      }
    } else {
      // в”Ђв”Ђ One-shot task: fire once on the due date (or next occurrence) в”Ђ
      tz.TZDateTime when;
      if (task.dueDate != null) {
        final d = task.dueDate!;
        when = tz.TZDateTime(tz.local, d.year, d.month, d.day,
            task.reminderTime!.hour, task.reminderTime!.minute);
        // If due date/time already passed, don't schedule (task is overdue)
        if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
      } else {
        when = _nextOccurrenceOfTime(task.reminderTime!);
      }

      await _plugin.zonedSchedule(
        _taskBaseId(task.id),
        'рџ“‹ ${task.title}',
        body,
        when,
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        // No matchDateTimeComponents = fires once, no repeat
        payload: 'task:${task.id}',
      );
      _log(
        id: 'task-${task.id}',
        type: NotifType.task,
        title: task.title,
        body: body,
        time: when.toLocal(),
      );
    }
  }

  /// Cancels all slots for a task.
  Future<void> cancelTask(String taskId) async {
    final base = _taskBaseId(taskId);
    await _plugin.cancel(base); // one-shot id
    for (var d = 1; d <= 7; d++) {
      await _plugin.cancel(base + d); // recurring per-weekday ids
    }
  }

  // в”Ђв”Ђ HABIT REMINDERS в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  //
  // Habits ARE repeating. A habit reminder fires:
  //   вЂў Every day at [reminderTime]  (if scheduleDays is empty)
  //   вЂў Every week on [scheduleDays] at [reminderTime]  (if scheduleDays set)
  // We log ONE entry per habit (the soonest upcoming fire time).
  //
  Future<void> scheduleHabitReminder(HabitModel habit) async {
    await cancelHabit(habit.id);
    if (habit.archived || habit.reminderTime == null) return;

    final days = habit.scheduleDays.isEmpty
        ? List.generate(7, (i) => i + 1)
        : habit.scheduleDays;

    tz.TZDateTime? earliest;
    for (final weekday in days) {
      final id = _habitBaseId(habit.id) + (weekday - 1);
      final when = _nextWeekday(weekday, habit.reminderTime!);
      await _plugin.zonedSchedule(
        id,
        '${habit.emoji} ${habit.name}',
        'Time to complete your habit!',
        when,
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'habit:${habit.id}',
      );
      if (earliest == null || when.isBefore(earliest)) earliest = when;
    }

    // Log only the SOONEST upcoming fire time (one entry per habit)
    if (earliest != null) {
      _log(
        id: 'habit-${habit.id}',
        type: NotifType.habit,
        title: '${habit.emoji} ${habit.name}',
        body: 'Time to complete your habit!',
        time: earliest.toLocal(),
      );
    }
  }

  /// Cancels all weekday slots for a habit.
  Future<void> cancelHabit(String habitId) async {
    final base = _habitBaseId(habitId);
    for (var i = 0; i < 7; i++) {
      await _plugin.cancel(base + i);
    }
  }

  // в”Ђв”Ђ GOAL DEADLINE REMINDERS в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  /// One-shot at 9 AM the morning before the deadline.
  Future<void> scheduleGoalDeadline(GoalModel goal) async {
    await cancelGoal(goal.id);
    if (goal.isComplete || goal.archived || goal.deadline == null) return;

    final reminderDay = goal.deadline!.subtract(const Duration(days: 1));
    final scheduled = tz.TZDateTime(tz.local, reminderDay.year,
        reminderDay.month, reminderDay.day, 9, 0);

    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _goalId(goal.id),
      'рџЋЇ ${goal.title}',
      'Deadline is tomorrow! Keep pushing!',
      scheduled,
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'goal:${goal.id}',
    );
    _log(
      id: 'goal-${goal.id}',
      type: NotifType.goal,
      title: 'рџЋЇ ${goal.title}',
      body: 'Deadline is tomorrow! Keep pushing!',
      time: scheduled.toLocal(),
    );
  }

  /// Cancels the goal deadline notification.
  Future<void> cancelGoal(String goalId) async {
    await _plugin.cancel(_goalId(goalId));
  }

  // в”Ђв”Ђ RESCHEDULE ALL (boot restore) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  /// Re-registers all OS alarms from Firestore data.
  /// Does NOT re-log entries (avoids flooding the notification center).
  Future<void> rescheduleAll({
    required List<TaskModel> tasks,
    required List<HabitModel> habits,
    required List<GoalModel> goals,
  }) async {
    await _plugin.cancelAll();
    for (final task in tasks) {
      if (!task.done) await _scheduleOnlyTask(task);
    }
    for (final habit in habits) {
      if (!habit.archived && !habit.isExpired) await _scheduleOnlyHabit(habit);
    }
    for (final goal in goals) {
      if (!goal.isComplete && !goal.archived) await _scheduleOnlyGoal(goal);
    }
  }

  // в”Ђв”Ђ Private: schedule without logging (used by rescheduleAll) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  Future<void> _scheduleOnlyTask(TaskModel task) async {
    if (task.done || task.reminderTime == null) return;
    final body =
    task.note?.isNotEmpty == true ? task.note! : 'Tap to open your task';

    if (task.reminderDays.isNotEmpty) {
      for (final weekday in task.reminderDays) {
        await _plugin.zonedSchedule(
          _taskBaseId(task.id) + weekday,
          'рџ“‹ ${task.title}', body,
          _nextWeekday(weekday, task.reminderTime!),
          _notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'task:${task.id}',
        );
      }
    } else {
      tz.TZDateTime when;
      if (task.dueDate != null) {
        final d = task.dueDate!;
        when = tz.TZDateTime(tz.local, d.year, d.month, d.day,
            task.reminderTime!.hour, task.reminderTime!.minute);
        if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
      } else {
        when = _nextOccurrenceOfTime(task.reminderTime!);
      }
      await _plugin.zonedSchedule(
        _taskBaseId(task.id),
        'рџ“‹ ${task.title}', body, when, _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task:${task.id}',
      );
    }
  }

  Future<void> _scheduleOnlyHabit(HabitModel habit) async {
    if (habit.archived || habit.reminderTime == null) return;
    final days = habit.scheduleDays.isEmpty
        ? List.generate(7, (i) => i + 1)
        : habit.scheduleDays;
    for (final weekday in days) {
      await _plugin.zonedSchedule(
        _habitBaseId(habit.id) + (weekday - 1),
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

  Future<void> _scheduleOnlyGoal(GoalModel goal) async {
    if (goal.isComplete || goal.archived || goal.deadline == null) return;
    final reminderDay = goal.deadline!.subtract(const Duration(days: 1));
    final scheduled = tz.TZDateTime(tz.local, reminderDay.year,
        reminderDay.month, reminderDay.day, 9, 0);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      _goalId(goal.id),
      'рџЋЇ ${goal.title}',
      'Deadline is tomorrow! Keep pushing!',
      scheduled, _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'goal:${goal.id}',
    );
  }

  // в”Ђв”Ђ Logging helper в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  void _log({
    required String id,
    required NotifType type,
    required String title,
    required String body,
    required DateTime time,
  }) {
    _container?.read(notificationLogProvider.notifier).add(
      id: id,
      type: type,
      title: title,
      body: body,
      time: time,
    );
  }
}
