import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import 'package:flutter/material.dart';

final _db = FirebaseFirestore.instance;
const _uuid = Uuid();

// ─── HELPERS ──────────────────────────────────────────────────────────────
CollectionReference _userCol(String uid, String col) =>
    _db.collection('users').doc(uid).collection(col);

// ─── USER PROFILE ─────────────────────────────────────────────────────────
class UserRepository {
  static Future<UserProfile?> get(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  static Future<void> create(UserProfile profile) =>
      _db.collection('users').doc(profile.uid).set(profile.toFirestore());

  static Future<void> update(String uid, Map<String, dynamic> fields) =>
      _db.collection('users').doc(uid).update(fields);

  static Stream<UserProfile?> stream(String uid) =>
      _db.collection('users').doc(uid).snapshots().map(
              (doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);

  static Future<void> addXp(String uid, XpSphere sphere, int xp) {
    final field = switch (sphere) {
      XpSphere.willpower => 'willpowerXp',
      XpSphere.intellect => 'intellectXp',
      XpSphere.health    => 'healthXp',
    };
    return _db.collection('users').doc(uid).update({
      field: FieldValue.increment(xp),
    });
  }

  static Future<void> addCustomCategory(String uid, String category) =>
      _db.collection('users').doc(uid).set({
        'customCategories': FieldValue.arrayUnion([category])
      }, SetOptions(merge: true));
}

// ─── TASKS ────────────────────────────────────────────────────────────────
class TaskRepository {
  static CollectionReference _col(String uid) => _userCol(uid, 'tasks');

  static Stream<List<TaskModel>> stream(String uid) =>
      _col(uid).orderBy('createdAt', descending: true).snapshots().map(
              (s) => s.docs.map((d) => TaskModel.fromFirestore(d)).toList());

  static Future<TaskModel> create(String uid, {
    required String title,
    String? note,
    int priority = 5,
    String category = 'Personal',
    DateTime? dueDate,
    List<SubTaskModel> subtasks = const [],
    XpSphere? xpSphere,      // null = auto-route from category
    int? xpReward,           // null = auto-compute from priority
  }) async {
    final id = _uuid.v4();
    final resolvedSphere = xpSphere ?? XpSphereExt.sphereForCategory(category);
    final resolvedReward = xpReward ?? XpSphereExt.xpForPriority(priority);
    final task = TaskModel(
      id: id, uid: uid, title: title, note: note,
      priority: priority, category: category, dueDate: dueDate,
      subtasks: subtasks, xpSphere: resolvedSphere, xpReward: resolvedReward,
      createdAt: DateTime.now(),
    );
    await _col(uid).doc(id).set(task.toFirestore());
    return task;
  }

  static Future<void> update(String uid, TaskModel task) =>
      _col(uid).doc(task.id).update(task.toFirestore());

  static Future<void> delete(String uid, String taskId) =>
      _col(uid).doc(taskId).delete();

  static Future<void> setDone(String uid, String taskId, bool done) =>
      _col(uid).doc(taskId).update({'done': done});
}

// ─── HABITS ───────────────────────────────────────────────────────────────
// ─── HABITS ───────────────────────────────────────────────────────────────
class HabitRepository {
  static CollectionReference _col(String uid) => _userCol(uid, 'habits');

  static Stream<List<HabitModel>> stream(String uid) =>
      _col(uid).orderBy('createdAt').snapshots().map(
            (s) => s.docs.map((d) => HabitModel.fromFirestore(d)).toList(),
      );

  static Future<HabitModel> create(
      String uid, {
        required String name,
        String emoji = '⭐',
        String category = 'Personal',
        int colorValue = 0xFF00C97B,
        List<int> scheduleDays = const [],
        XpSphere? xpSphere,   // null = auto-route from category
        int xpReward = 15,
        String? note,
        TimeOfDay? reminderTime,
        bool isUnlimited = true,
        int? durationDays,
      }) async {
    final id = _uuid.v4();
    final resolvedSphere = xpSphere ?? XpSphereExt.sphereForCategory(category);

    final habit = HabitModel(
      id: id,
      uid: uid,
      name: name,
      emoji: emoji,
      category: category,
      colorValue: colorValue,
      scheduleDays: scheduleDays,
      reminderTime: reminderTime,
      note: note,
      xpSphere: resolvedSphere,
      xpReward: xpReward,
      isUnlimited: isUnlimited,
      durationDays: durationDays,
      createdAt: DateTime.now(),
    );

    await _col(uid).doc(id).set(habit.toFirestore());
    return habit;
  }

  static Future<void> update(String uid, HabitModel habit) =>
      _col(uid).doc(habit.id).update(habit.toFirestore());

  static Future<void> delete(String uid, String habitId) =>
      _col(uid).doc(habitId).delete();

  /// Toggle completion for today — recalculates streak
  static Future<HabitModel> toggleToday(String uid, HabitModel habit) async {
    final today = _dateKey(DateTime.now());
    final dates = List<String>.from(habit.completionDates);

    if (dates.contains(today)) {
      dates.remove(today);
    } else {
      dates.add(today);
    }

    final newStreak = _calcStreak(dates);
    final newBest = newStreak > habit.bestStreak ? newStreak : habit.bestStreak;

    final updated = habit.copyWith(
      completionDates: dates,
      streak: newStreak,
      bestStreak: newBest,
    );

    await _col(uid).doc(habit.id).update(updated.toFirestore());
    return updated;
  }

  static int _calcStreak(List<String> dates) {
    if (dates.isEmpty) return 0;
    final sorted = [...dates]..sort();
    int streak = 0;
    DateTime check = DateTime.now();

    while (true) {
      final key = _dateKey(check);
      if (sorted.contains(key)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── GOALS ────────────────────────────────────────────────────────────────
class GoalRepository {
  static CollectionReference _col(String uid) => _userCol(uid, 'goals');

  static Stream<List<GoalModel>> stream(String uid) =>
      _col(uid).orderBy('createdAt', descending: true).snapshots().map(
              (s) => s.docs.map((d) => GoalModel.fromFirestore(d)).toList());

  static Future<GoalModel> create(String uid, {
    required String title,
    String category = 'Personal',
    String emoji = '🎯',
    int colorValue = 0xFF00C97B,
    String? note,
    DateTime? deadline,
    List<GoalStepModel> steps = const [],
    XpSphere? xpSphere,   // null = auto-route from category
    int xpReward = 50,
    String? customReward,
    double? measureTarget,
    String? measureUnit,
  }) async {
    final id = _uuid.v4();
    final resolvedSphere = xpSphere ?? XpSphereExt.sphereForCategory(category);
    final goal = GoalModel(
      id: id, uid: uid, title: title, category: category,
      emoji: emoji, colorValue: colorValue, note: note,
      deadline: deadline, steps: steps, xpSphere: resolvedSphere,
      xpReward: xpReward, customReward: customReward,
      measureTarget: measureTarget, measureUnit: measureUnit,
      createdAt: DateTime.now(),
    );
    await _col(uid).doc(id).set(goal.toFirestore());
    return goal;
  }

  static Future<void> update(String uid, GoalModel goal) =>
      _col(uid).doc(goal.id).update(goal.toFirestore());

  static Future<void> delete(String uid, String goalId) =>
      _col(uid).doc(goalId).delete();
}

// ─── POMODORO ─────────────────────────────────────────────────────────────
class PomodoroRepository {
  static CollectionReference _col(String uid) =>
      _userCol(uid, 'pomodoro_sessions');

  static Stream<List<PomodoroSession>> streamRecent(String uid, {int days = 30}) {
    final since = Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: days)),
    );

    return _col(uid)
        .where('date', isGreaterThan: since)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (s) => s.docs.map((d) => PomodoroSession.fromFirestore(d)).toList(),
    );
  }

  static Future<void> logSession(
      String uid, {
        required int durationMinutes,
        String? linkedTaskId,
        String? linkedTaskTitle,
      }) async {
    final id = _uuid.v4();

    final session = PomodoroSession(
      id: id,
      uid: uid,
      date: DateTime.now(),
      durationMinutes: durationMinutes,
      linkedTaskId: linkedTaskId,
      linkedTaskTitle: linkedTaskTitle,
    );

    await _col(uid).doc(id).set(session.toFirestore());
  }
}

// ─── LIFE BALANCE ─────────────────────────────────────────────────────────
class LifeBalanceRepository {
  static CollectionReference _col(String uid) => _userCol(uid, 'life_balance');

  static Stream<List<LifeBalanceSnapshot>> stream(String uid) =>
      _col(uid).orderBy('date', descending: true).snapshots().map(
              (s) => s.docs.map((d) => LifeBalanceSnapshot.fromFirestore(d)).toList());

  static Future<void> saveSnapshot(String uid, Map<String, double> scores) async {
    final now = DateTime.now();
    // Use date as document ID so saving today always overwrites — one entry per day max
    final id = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final snap = LifeBalanceSnapshot(
        id: id, uid: uid, date: now, scores: scores);
    await _col(uid).doc(id).set(snap.toFirestore());
  }
}