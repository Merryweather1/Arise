import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── NOTIFICATION ENTRY MODEL ─────────────────────────────────────────────
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
}

// ─── PROVIDER ────────────────────────────────────────────────────────────
const _kPrefKey = 'arise_notification_log';
const _kMaxEntries = 50; // keep last 50

class NotificationLogNotifier extends Notifier<List<NotificationEntry>> {
  @override
  List<NotificationEntry> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => NotificationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    state = list;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPrefKey, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  /// Add a new notification entry (called when scheduling a notification).
  Future<void> add({
    required String id,
    required NotifType type,
    required String title,
    required String body,
    DateTime? time,
  }) async {
    final entry = NotificationEntry(
      id: id,
      type: type,
      title: title,
      body: body,
      time: time ?? DateTime.now(),
    );
    // Prepend; remove duplicates by id; cap at max
    final updated = [entry, ...state.where((e) => e.id != id)];
    state =
        updated.length > _kMaxEntries ? updated.sublist(0, _kMaxEntries) : updated;
    await _save();
  }

  /// Mark all as read.
  Future<void> markAllRead() async {
    state = state.map((e) => e.copyWith(read: true)).toList();
    await _save();
  }

  /// Remove a single entry.
  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }

  /// Clear everything.
  Future<void> clearAll() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
  }

  int get unreadCount => state.where((e) => !e.read).length;
}

final notificationLogProvider =
    NotifierProvider<NotificationLogNotifier, List<NotificationEntry>>(
        NotificationLogNotifier.new);

/// Convenience: how many unread entries are there right now.
final notifUnreadCountProvider = Provider<int>((ref) {
  final entries = ref.watch(notificationLogProvider);
  return entries.where((e) => !e.read).length;
});
