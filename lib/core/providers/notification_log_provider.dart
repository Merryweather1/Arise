import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotifType { task, habit, goal }

class NotificationEntry {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime time;
  final bool read;

  const NotificationEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  NotificationEntry copyWith({bool? read}) => NotificationEntry(
    id: id,
    type: type,
    title: title,
    body: body,
    time: time,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'time': time.toIso8601String(),
    'read': read,
  };

  factory NotificationEntry.fromJson(Map<String, dynamic> j) =>
      NotificationEntry(
        id: j['id'] as String,
        type: NotifType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => NotifType.task),
        title: j['title'] as String,
        body: j['body'] as String,
        time: DateTime.parse(j['time'] as String),
        read: j['read'] as bool? ?? false,
      );

  bool get hasFired => !time.isAfter(DateTime.now());
}

const _kPrefKey = 'arise_notification_log';
const _kMaxEntries = 50;

class NotificationLogNotifier extends Notifier<List<NotificationEntry>> {
  late Future<void> _ready;

  @override
  List<NotificationEntry> build() {
    _ready = _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => NotificationEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {
      await prefs.remove(_kPrefKey);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPrefKey, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> add({
    required String id,
    required NotifType type,
    required String title,
    required String body,
    DateTime? time,
  }) async {
    await _ready;
    final entry = NotificationEntry(
      id: id,
      type: type,
      title: title,
      body: body,
      time: time ?? DateTime.now(),
    );
    final updated = [entry, ...state.where((e) => e.id != id)];
    state = updated.length > _kMaxEntries
        ? updated.sublist(0, _kMaxEntries)
        : updated;
    await _save();
  }

  Future<void> markAllRead() async {
    await _ready;
    final now = DateTime.now();
    state = state.map((e) {
      if (!e.time.isAfter(now)) return e.copyWith(read: true);
      return e;
    }).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    await _ready;
    final before = state.length;
    state = state.where((e) => e.id != id).toList();
    if (state.length != before) await _save();
  }

  Future<void> clearFired() async {
    await _ready;
    state = state.where((e) => e.time.isAfter(DateTime.now())).toList();
    await _save();
  }

  Future<void> clearAll() async {
    await _ready;
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
  }

  Future<void> purgeOldHabitEntries() async {
    await _ready;
    final todayMidnight = () {
      final d = DateTime.now();
      return DateTime(d.year, d.month, d.day);
    }();
    bool changed = false;
    state = state.where((e) {
      if (e.type != NotifType.habit) return true;
      if (!e.hasFired) return true;
      final firedDay = DateTime(e.time.year, e.time.month, e.time.day);
      if (firedDay.isBefore(todayMidnight)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();
    if (changed) await _save();
  }
}


final notificationLogProvider =
NotifierProvider<NotificationLogNotifier, List<NotificationEntry>>(
    NotificationLogNotifier.new);

final notifUnreadCountProvider = Provider<int>((ref) {
  final entries = ref.watch(notificationLogProvider);
  final now = DateTime.now();
  return entries.where((e) => !e.read && !e.time.isAfter(now)).length;
});
