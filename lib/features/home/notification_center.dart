import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/notification_log_provider.dart';
import '../../core/theme/app_theme.dart';

// ─── PUBLIC ENTRY POINT ───────────────────────────────────────────────────
void showNotificationCenter(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withAlpha(160),
    useRootNavigator: true,
    builder: (_) => const _NotificationCenterSheet(),
  );
}

// ─── SHEET ────────────────────────────────────────────────────────────────
class _NotificationCenterSheet extends ConsumerStatefulWidget {
  const _NotificationCenterSheet();

  @override
  ConsumerState<_NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState
    extends ConsumerState<_NotificationCenterSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(notificationLogProvider.notifier);
      // Purge habit entries from previous days (habits reset each cycle)
      notifier.purgeOldHabitEntries();
      // Mark all currently-fired entries as read
      notifier.markAllRead();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Map<String, List<NotificationEntry>> _grouped(
      List<NotificationEntry> entries) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    final Map<String, List<NotificationEntry>> groups = {};
    for (final e in entries) {
      final d = DateTime(e.time.year, e.time.month, e.time.day);
      final String key;
      if (d == todayDate) {
        key = 'Today';
      } else if (d == yesterdayDate) {
        key = 'Yesterday';
      } else {
        key = DateFormat('EEEE, MMM d').format(e.time);
      }
      groups.putIfAbsent(key, () => []).add(e);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(notificationLogProvider);
    // Only show entries that have actually fired
    final entries = allEntries.where((e) => e.hasFired).toList();
    final grouped = _grouped(entries);
    final sections = grouped.entries.toList();

    return FadeTransition(
      opacity: _fade,
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(
                    color: AColors.primary.withAlpha(60), width: 1.5),
              ),
            ),
            child: Column(
              children: [
                // ── Handle + Header ──────────────────────────────────────
                _buildHeader(entries, ctx),
                const Divider(color: Color(0xFF1E2128), height: 1),

                // ── Body ────────────────────────────────────────────────
                Expanded(
                  child: entries.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.only(bottom: 32),
                          itemCount: sections.fold<int>(
                              0, (s, g) => s + 1 + g.value.length),
                          itemBuilder: (_, rawIndex) {
                            // Map flat index to section + item
                            int idx = rawIndex;
                            for (final section in sections) {
                              if (idx == 0) {
                                return _SectionLabel(section.key);
                              }
                              idx--;
                              if (idx < section.value.length) {
                                return _NotifTile(
                                  entry: section.value[idx],
                                  animIndex: rawIndex,
                                  onDismiss: () {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(notificationLogProvider.notifier)
                                        .remove(section.value[idx].id);
                                  },
                                );
                              }
                              idx -= section.value.length;
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(List<NotificationEntry> entries, BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 16),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2E3A),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Icon + Title
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AColors.primary.withAlpha(40),
                      AColors.primary.withAlpha(15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AColors.primary.withAlpha(50), width: 1),
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: AColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notification Center',
                        style: TextStyle(
                          color: AColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        )),
                    Text(
                      entries.isEmpty
                          ? 'All caught up'
                          : '${entries.length} reminder${entries.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    // Only clear fired ones; keeps future-scheduled pending
                    ref.read(notificationLogProvider.notifier).clearFired();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    foregroundColor: AColors.textMuted,
                  ),
                  child: const Text('Clear all',
                      style: TextStyle(fontSize: 13, color: AColors.textMuted)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AColors.primary.withAlpha(25),
                  AColors.primary.withAlpha(8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AColors.primary.withAlpha(40), width: 1.5),
            ),
            child: const Icon(Icons.notifications_off_rounded,
                color: AColors.primary, size: 30),
          ),
          const SizedBox(height: 20),
          const Text('All caught up!',
              style: TextStyle(
                color: AColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          const Text(
            'Notifications appear here\nonce their reminder fires.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AColors.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION LABEL ────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── NOTIFICATION TILE ────────────────────────────────────────────────────
class _NotifTile extends StatefulWidget {
  final NotificationEntry entry;
  final int animIndex;
  final VoidCallback onDismiss;

  const _NotifTile({
    required this.entry,
    required this.animIndex,
    required this.onDismiss,
  });

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 40 * widget.animIndex.clamp(0, 12));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<double>(begin: 24, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _typeColor {
    switch (widget.entry.type) {
      case NotifType.task:
        return const Color(0xFF00C97B);
      case NotifType.habit:
        return const Color(0xFF7B61FF);
      case NotifType.goal:
        return const Color(0xFFFFB800);
    }
  }

  IconData get _typeIcon {
    switch (widget.entry.type) {
      case NotifType.task:
        return Icons.check_circle_outline_rounded;
      case NotifType.habit:
        return Icons.loop_rounded;
      case NotifType.goal:
        return Icons.flag_rounded;
    }
  }

  String get _typeLabel {
    switch (widget.entry.type) {
      case NotifType.task:
        return 'Task';
      case NotifType.habit:
        return 'Habit';
      case NotifType.goal:
        return 'Goal';
    }
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return DateFormat('h:mm a').format(t);
    return DateFormat('MMM d, h:mm a').format(t);
  }

  /// Task reminders that fired >6 h ago without being dismissed = overdue.
  bool get _isOverdue {
    if (widget.entry.type != NotifType.task) return false;
    return DateTime.now().difference(widget.entry.time).inHours >= 6;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: Dismissible(
        key: Key(widget.entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(40),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.red, size: 22),
        ),
        onDismissed: (_) => widget.onDismiss(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF16191F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _typeColor.withAlpha(widget.entry.read ? 18 : 50),
              width: widget.entry.read ? 1 : 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => HapticFeedback.selectionClick(),
              splashColor: _typeColor.withAlpha(20),
              highlightColor: _typeColor.withAlpha(10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon bubble
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _typeColor.withAlpha(50),
                            _typeColor.withAlpha(20),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: _typeColor.withAlpha(60), width: 1),
                      ),
                      child: Icon(_typeIcon, color: _typeColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _typeColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _typeColor.withAlpha(50),
                                      width: 1),
                                ),
                                child: Text(
                                  _typeLabel,
                                  style: TextStyle(
                                    color: _typeColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              // Overdue badge for stale task reminders
                              if (_isOverdue) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB800).withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: const Color(0xFFFFB800).withAlpha(80),
                                        width: 1),
                                  ),
                                  child: const Text(
                                    'OVERDUE',
                                    style: TextStyle(
                                      color: Color(0xFFFFB800),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                _formatTime(widget.entry.time),
                                style: const TextStyle(
                                  color: AColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.entry.title,
                            style: TextStyle(
                              color: widget.entry.read
                                  ? AColors.textSecondary
                                  : AColors.textPrimary,
                              fontWeight: widget.entry.read
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.entry.body,
                            style: const TextStyle(
                              color: AColors.textMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Fired-at time chip
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.notifications_active_rounded,
                                  size: 11, color: _typeColor.withAlpha(180)),
                              const SizedBox(width: 4),
                              Text(
                                'Fired at ${DateFormat('EEE, MMM d \u00b7 h:mm a').format(widget.entry.time)}',
                                style: TextStyle(
                                  color: _isOverdue
                                      ? const Color(0xFFFFB800).withAlpha(200)
                                      : _typeColor.withAlpha(200),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
