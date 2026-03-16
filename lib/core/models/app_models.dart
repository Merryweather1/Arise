import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─── USER PROFILE ─────────────────────────────────────────────────────────
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;

  // 3-sphere XP
  final int willpowerXp;
  final int intellectXp;
  final int healthXp;

  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.willpowerXp = 0,
    this.intellectXp = 0,
    this.healthXp = 0,
    required this.createdAt,
  });

  int get willpowerLevel => _xpToLevel(willpowerXp);
  int get intellectLevel  => _xpToLevel(intellectXp);
  int get healthLevel     => _xpToLevel(healthXp);

  int get willpowerNextLevelXp => _nextLevelXp(willpowerLevel);
  int get intellectNextLevelXp  => _nextLevelXp(intellectLevel);
  int get healthNextLevelXp     => _nextLevelXp(healthLevel);

  int get willpowerLevelXp => _levelStartXp(willpowerLevel);
  int get intellectLevelXp  => _levelStartXp(intellectLevel);
  int get healthLevelXp     => _levelStartXp(healthLevel);

  static int _xpToLevel(int xp) {
    int level = 1;
    int required = 100;
    int total = 0;
    while (total + required <= xp) {
      total += required;
      level++;
      required = (required * 1.25).round();
    }
    return level;
  }

  static int _nextLevelXp(int level) {
    int required = 100;
    for (int i = 1; i < level; i++) required = (required * 1.25).round();
    return required;
  }

  static int _levelStartXp(int level) {
    int total = 0;
    int required = 100;
    for (int i = 1; i < level; i++) {
      total += required;
      required = (required * 1.25).round();
    }
    return total;
  }

  double get willpowerProgress {
    final start = _levelStartXp(willpowerLevel);
    final next = _nextLevelXp(willpowerLevel);
    return next == 0 ? 0 : ((willpowerXp - start) / next).clamp(0.0, 1.0);
  }

  double get intellectProgress {
    final start = _levelStartXp(intellectLevel);
    final next = _nextLevelXp(intellectLevel);
    return next == 0 ? 0 : ((intellectXp - start) / next).clamp(0.0, 1.0);
  }

  double get healthProgress {
    final start = _levelStartXp(healthLevel);
    final next = _nextLevelXp(healthLevel);
    return next == 0 ? 0 : ((healthXp - start) / next).clamp(0.0, 1.0);
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: d['name'] ?? 'Warrior',
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'],
      willpowerXp: d['willpowerXp'] ?? 0,
      intellectXp: d['intellectXp'] ?? 0,
      healthXp: d['healthXp'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
    'willpowerXp': willpowerXp,
    'intellectXp': intellectXp,
    'healthXp': healthXp,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  UserProfile copyWith({
    String? name, String? photoUrl,
    int? willpowerXp, int? intellectXp, int? healthXp,
  }) => UserProfile(
    uid: uid, email: email, createdAt: createdAt,
    name: name ?? this.name,
    photoUrl: photoUrl ?? this.photoUrl,
    willpowerXp: willpowerXp ?? this.willpowerXp,
    intellectXp: intellectXp ?? this.intellectXp,
    healthXp: healthXp ?? this.healthXp,
  );
}

// ─── XP SPHERE ────────────────────────────────────────────────────────────
enum XpSphere { willpower, intellect, health }

extension XpSphereExt on XpSphere {
  String get label => switch (this) {
    XpSphere.willpower => 'Willpower',
    XpSphere.intellect => 'Intellect',
    XpSphere.health    => 'Health',
  };
  String get emoji => switch (this) {
    XpSphere.willpower => '🔥',
    XpSphere.intellect => '🧠',
    XpSphere.health    => '❤️',
  };
  Color get color => switch (this) {
    XpSphere.willpower => const Color(0xFFFF6B35),
    XpSphere.intellect => const Color(0xFF4D9FFF),
    XpSphere.health    => const Color(0xFF00C97B),
  };
}

// ─── TASK ─────────────────────────────────────────────────────────────────
class SubTaskModel {
  final String id;
  final String title;
  final bool done;

  const SubTaskModel({required this.id, required this.title, this.done = false});

  factory SubTaskModel.fromMap(Map<String, dynamic> m) =>
      SubTaskModel(id: m['id'] ?? '', title: m['title'] ?? '', done: m['done'] ?? false);

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'done': done};

  SubTaskModel copyWith({String? title, bool? done}) =>
      SubTaskModel(id: id, title: title ?? this.title, done: done ?? this.done);
}

class TaskModel {
  final String id;
  final String uid;
  final String title;
  final String? note;
  final bool done;
  final bool pending;
  final int priority;       // 1–10
  final String category;
  final DateTime? dueDate;
  final TimeOfDay? reminderTime;
  final List<int> reminderDays;
  final List<SubTaskModel> subtasks;
  final XpSphere xpSphere;
  final int xpReward;
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.uid,
    required this.title,
    this.note,
    this.done = false,
    this.pending = false,
    this.priority = 5,
    this.category = 'Personal',
    this.dueDate,
    this.reminderTime,
    this.reminderDays = const [],
    this.subtasks = const [],
    this.xpSphere = XpSphere.willpower,
    this.xpReward = 10,
    required this.createdAt,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    TimeOfDay? reminder;
    if (d['reminderHour'] != null) {
      reminder = TimeOfDay(hour: d['reminderHour'], minute: d['reminderMinute'] ?? 0);
    }
    return TaskModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      title: d['title'] ?? '',
      note: d['note'],
      done: d['done'] ?? false,
      pending: d['pending'] ?? false,
      priority: d['priority'] ?? 5,
      category: d['category'] ?? 'Personal',
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      reminderTime: reminder,
      reminderDays: List<int>.from(d['reminderDays'] ?? []),
      subtasks: (d['subtasks'] as List? ?? [])
          .map((s) => SubTaskModel.fromMap(s as Map<String, dynamic>)).toList(),
      xpSphere: XpSphere.values.firstWhere(
              (s) => s.name == (d['xpSphere'] ?? 'willpower'),
          orElse: () => XpSphere.willpower),
      xpReward: d['xpReward'] ?? 10,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid, 'title': title, 'note': note,
    'done': done, 'pending': pending, 'priority': priority,
    'category': category,
    'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    'reminderHour': reminderTime?.hour,
    'reminderMinute': reminderTime?.minute,
    'reminderDays': reminderDays,
    'subtasks': subtasks.map((s) => s.toMap()).toList(),
    'xpSphere': xpSphere.name,
    'xpReward': xpReward,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  TaskModel copyWith({
    String? title, String? note, bool? done, bool? pending,
    int? priority, String? category, DateTime? dueDate,
    TimeOfDay? reminderTime, List<int>? reminderDays,
    List<SubTaskModel>? subtasks, XpSphere? xpSphere, int? xpReward,
    bool clearDueDate = false, bool clearReminder = false,
  }) => TaskModel(
    id: id, uid: uid, createdAt: createdAt,
    title: title ?? this.title,
    note: note ?? this.note,
    done: done ?? this.done,
    pending: pending ?? this.pending,
    priority: priority ?? this.priority,
    category: category ?? this.category,
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
    reminderDays: reminderDays ?? this.reminderDays,
    subtasks: subtasks ?? this.subtasks,
    xpSphere: xpSphere ?? this.xpSphere,
    xpReward: xpReward ?? this.xpReward,
  );
}

// ─── HABIT ────────────────────────────────────────────────────────────────
class HabitModel {
  final String id;
  final String uid;
  final String name;
  final String emoji;
  final String category;
  final int colorValue;
  final int streak;
  final int bestStreak;
  final List<int> scheduleDays; // 1=Mon..7=Sun, empty=daily
  final TimeOfDay? reminderTime;
  final String? note;
  final List<String> completionDates; // "yyyy-MM-dd"
  final XpSphere xpSphere;
  final int xpReward;
  final bool archived;
  final bool isUnlimited;
  final int? durationDays; // null if unlimited
  final DateTime createdAt;

  const HabitModel({
    required this.id,
    required this.uid,
    required this.name,
    this.emoji = '⭐',
    this.category = 'Personal',
    this.colorValue = 0xFF00C97B,
    this.streak = 0,
    this.bestStreak = 0,
    this.scheduleDays = const [],
    this.reminderTime,
    this.note,
    this.completionDates = const [],
    this.xpSphere = XpSphere.willpower,
    this.xpReward = 15,
    this.archived = false,
    this.isUnlimited = true,
    this.durationDays,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  bool isCompletedOn(DateTime date) {
    final key = _dateKey(date);
    return completionDates.contains(key);
  }

  bool get isExpired {
    if (isUnlimited) return false;
    if (durationDays == null || durationDays! <= 0) return false;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startOnly = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final endInclusive = startOnly.add(Duration(days: durationDays! - 1));

    return todayOnly.isAfter(endInclusive);
  }

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory HabitModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    TimeOfDay? reminder;
    if (d['reminderHour'] != null) {
      reminder = TimeOfDay(
        hour: d['reminderHour'],
        minute: d['reminderMinute'] ?? 0,
      );
    }

    return HabitModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '⭐',
      category: d['category'] ?? 'Personal',
      colorValue: d['colorValue'] ?? 0xFF00C97B,
      streak: d['streak'] ?? 0,
      bestStreak: d['bestStreak'] ?? 0,
      scheduleDays: List<int>.from(d['scheduleDays'] ?? []),
      reminderTime: reminder,
      note: d['note'],
      completionDates: List<String>.from(d['completionDates'] ?? []),
      xpSphere: XpSphere.values.firstWhere(
            (s) => s.name == (d['xpSphere'] ?? 'willpower'),
        orElse: () => XpSphere.willpower,
      ),
      xpReward: d['xpReward'] ?? 15,
      archived: d['archived'] ?? false,
      isUnlimited: d['isUnlimited'] ?? true,
      durationDays: d['durationDays'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'name': name,
    'emoji': emoji,
    'category': category,
    'colorValue': colorValue,
    'streak': streak,
    'bestStreak': bestStreak,
    'scheduleDays': scheduleDays,
    'reminderHour': reminderTime?.hour,
    'reminderMinute': reminderTime?.minute,
    'note': note,
    'completionDates': completionDates,
    'xpSphere': xpSphere.name,
    'xpReward': xpReward,
    'archived': archived,
    'isUnlimited': isUnlimited,
    'durationDays': durationDays,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  HabitModel copyWith({
    String? name,
    String? emoji,
    String? category,
    int? colorValue,
    int? streak,
    int? bestStreak,
    List<int>? scheduleDays,
    TimeOfDay? reminderTime,
    String? note,
    List<String>? completionDates,
    XpSphere? xpSphere,
    int? xpReward,
    bool? archived,
    bool? isUnlimited,
    int? durationDays,
    bool clearReminder = false,
  }) =>
      HabitModel(
        id: id,
        uid: uid,
        createdAt: createdAt,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        category: category ?? this.category,
        colorValue: colorValue ?? this.colorValue,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        scheduleDays: scheduleDays ?? this.scheduleDays,
        reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
        note: note ?? this.note,
        completionDates: completionDates ?? this.completionDates,
        xpSphere: xpSphere ?? this.xpSphere,
        xpReward: xpReward ?? this.xpReward,
        archived: archived ?? this.archived,
        isUnlimited: isUnlimited ?? this.isUnlimited,
        durationDays: durationDays ?? this.durationDays,
      );
}

// ─── GOAL ─────────────────────────────────────────────────────────────────
class GoalStepModel {
  final String id;
  final String title;
  final bool done;
  const GoalStepModel({required this.id, required this.title, this.done = false});
  factory GoalStepModel.fromMap(Map<String, dynamic> m) =>
      GoalStepModel(id: m['id'] ?? '', title: m['title'] ?? '', done: m['done'] ?? false);
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'done': done};
  GoalStepModel copyWith({String? title, bool? done}) =>
      GoalStepModel(id: id, title: title ?? this.title, done: done ?? this.done);
}

class GoalModel {
  final String id;
  final String uid;
  final String title;
  final String category;
  final String emoji;
  final int colorValue;
  final String? note;
  final DateTime? deadline;
  final List<GoalStepModel> steps;
  final bool archived;
  final bool manuallyComplete;
  final int xpReward;
  final String? customReward;
  final double? measureTarget;
  final String? measureUnit;
  final double measureCurrent;
  final XpSphere xpSphere;
  final DateTime createdAt;

  const GoalModel({
    required this.id,
    required this.uid,
    required this.title,
    this.category = 'Personal',
    this.emoji = '🎯',
    this.colorValue = 0xFF00C97B,
    this.note,
    this.deadline,
    this.steps = const [],
    this.archived = false,
    this.manuallyComplete = false,
    this.xpReward = 50,
    this.customReward,
    this.measureTarget,
    this.measureUnit,
    this.measureCurrent = 0,
    this.xpSphere = XpSphere.willpower,
    required this.createdAt,
  });

  double get progress {
    if (manuallyComplete) return 1.0;
    if (measureTarget != null && measureTarget! > 0) {
      return (measureCurrent / measureTarget!).clamp(0.0, 1.0);
    }
    if (steps.isEmpty) return 0.0;
    return steps.where((s) => s.done).length / steps.length;
  }

  bool get isComplete => manuallyComplete || progress >= 1.0;

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GoalModel(
      id: doc.id, uid: d['uid'] ?? '', title: d['title'] ?? '',
      category: d['category'] ?? 'Personal',
      emoji: d['emoji'] ?? '🎯', colorValue: d['colorValue'] ?? 0xFF00C97B,
      note: d['note'], deadline: (d['deadline'] as Timestamp?)?.toDate(),
      steps: (d['steps'] as List? ?? [])
          .map((s) => GoalStepModel.fromMap(s as Map<String, dynamic>)).toList(),
      archived: d['archived'] ?? false,
      manuallyComplete: d['manuallyComplete'] ?? false,
      xpReward: d['xpReward'] ?? 50, customReward: d['customReward'],
      measureTarget: (d['measureTarget'] as num?)?.toDouble(),
      measureUnit: d['measureUnit'],
      measureCurrent: (d['measureCurrent'] as num?)?.toDouble() ?? 0,
      xpSphere: XpSphere.values.firstWhere(
              (s) => s.name == (d['xpSphere'] ?? 'willpower'),
          orElse: () => XpSphere.willpower),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid, 'title': title, 'category': category,
    'emoji': emoji, 'colorValue': colorValue, 'note': note,
    'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
    'steps': steps.map((s) => s.toMap()).toList(),
    'archived': archived, 'manuallyComplete': manuallyComplete,
    'xpReward': xpReward, 'customReward': customReward,
    'measureTarget': measureTarget, 'measureUnit': measureUnit,
    'measureCurrent': measureCurrent, 'xpSphere': xpSphere.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  GoalModel copyWith({
    String? title, String? category, String? emoji, int? colorValue,
    String? note, DateTime? deadline, List<GoalStepModel>? steps,
    bool? archived, bool? manuallyComplete, int? xpReward,
    String? customReward, double? measureTarget, String? measureUnit,
    double? measureCurrent, XpSphere? xpSphere,
  }) => GoalModel(
    id: id, uid: uid, createdAt: createdAt,
    title: title ?? this.title, category: category ?? this.category,
    emoji: emoji ?? this.emoji, colorValue: colorValue ?? this.colorValue,
    note: note ?? this.note, deadline: deadline ?? this.deadline,
    steps: steps ?? this.steps, archived: archived ?? this.archived,
    manuallyComplete: manuallyComplete ?? this.manuallyComplete,
    xpReward: xpReward ?? this.xpReward, customReward: customReward ?? this.customReward,
    measureTarget: measureTarget ?? this.measureTarget,
    measureUnit: measureUnit ?? this.measureUnit,
    measureCurrent: measureCurrent ?? this.measureCurrent,
    xpSphere: xpSphere ?? this.xpSphere,
  );
}

// ─── POMODORO SESSION ─────────────────────────────────────────────────────
class PomodoroSession {
  final String id;
  final String uid;
  final DateTime date;
  final int durationMinutes;
  final String? linkedTaskId;
  final String? linkedTaskTitle;

  const PomodoroSession({
    required this.id,
    required this.uid,
    required this.date,
    required this.durationMinutes,
    this.linkedTaskId,
    this.linkedTaskTitle,
  });

  factory PomodoroSession.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PomodoroSession(
      id: doc.id,
      uid: d['uid'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: d['durationMinutes'] ?? 0,
      linkedTaskId: d['linkedTaskId'],
      linkedTaskTitle: d['linkedTaskTitle'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'date': Timestamp.fromDate(date),
    'durationMinutes': durationMinutes,
    'linkedTaskId': linkedTaskId,
    'linkedTaskTitle': linkedTaskTitle,
  };
}

// ─── LIFE BALANCE SNAPSHOT ────────────────────────────────────────────────
class LifeBalanceSnapshot {
  final String id;
  final String uid;
  final DateTime date;
  final Map<String, double> scores; // sphere name → score 0–10

  const LifeBalanceSnapshot({
    required this.id, required this.uid,
    required this.date, required this.scores,
  });

  double get average =>
      scores.isEmpty ? 0 : scores.values.fold(0.0, (a, b) => a + b) / scores.length;

  factory LifeBalanceSnapshot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LifeBalanceSnapshot(
      id: doc.id, uid: d['uid'] ?? '',
      date: (d['date'] as Timestamp).toDate(),
      scores: Map<String, double>.from(
          (d['scores'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'date': Timestamp.fromDate(date),
    'scores': scores,
  };
}
