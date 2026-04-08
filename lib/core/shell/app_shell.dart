import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../router/app_router.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = [
    ARoutes.home,
    ARoutes.tasks,
    ARoutes.habits,
    ARoutes.goals,
    ARoutes.pomodoro,
  ];

  static const _icons = [
    Icons.home_rounded,
    Icons.check_circle_outline_rounded,
    Icons.loop_rounded,
    Icons.flag_rounded,
    Icons.timer_rounded,
  ];

  static const _labels = ['Home', 'Tasks', 'Habits', 'Goals', 'Focus'];

  OverlayEntry? _xpPillEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(xpEventProvider, (previous, next) {
        if (next == null) return;
        if (next.isLevelUp) {
          _showLevelUpSheet(next);
        } else {
          _showXpPill(next);
        }
      });
    });
  }

  void _showXpPill(XpEvent event) {
    _xpPillEntry?.remove();
    _xpPillEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _XpPillOverlay(
        event: event,
        onDone: () {
          try { entry.remove(); } catch (_) {}
          if (_xpPillEntry == entry) _xpPillEntry = null;
        },
      ),
    );
    _xpPillEntry = entry;
    overlay.insert(entry);
  }

  void _showLevelUpSheet(XpEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LevelUpSheet(event: event),
    );
  }

  int _currentIndex(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _currentIndex(location);

    // Activate the startup re-schedule provider (watches tasks/habits/goals
    // and re-registers all notifications once data loads from Firestore).
    ref.watch(notificationBootProvider);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != 0) context.go(ARoutes.home);
      },
      child: Scaffold(
        backgroundColor: AColors.bg,
        body: widget.child,
        // Glassmorphic Bottom Navigation Bar
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AColors.bgCard.withValues(alpha: 0.85),
                border: const Border(top: BorderSide(color: AColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_tabs.length, (i) {
                      final selected = i == currentIndex;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.go(_tabs[i]);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 1.0, end: selected ? 1.1 : 1.0),
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AColors.primary.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: ARadius.md,
                                  ),
                                  child: Icon(
                                    _icons[i],
                                    size: 22,
                                    color: selected
                                        ? AColors.primary
                                        : AColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _labels[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? AColors.primary
                                        : AColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── XP PILL OVERLAY ─────────────────────────────────────────────────────
class _XpPillOverlay extends StatefulWidget {
  final XpEvent event;
  final VoidCallback onDone;
  const _XpPillOverlay({required this.event, required this.onDone});

  @override
  State<_XpPillOverlay> createState() => _XpPillOverlayState();
}

class _XpPillOverlayState extends State<_XpPillOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);
    _slide = Tween(begin: 0.0, end: -48.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sphere = widget.event.sphere;
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _slide.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: sphere.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: sphere.color.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: sphere.color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sphereIcon(sphere),
                      size: 15,
                      color: sphere.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${widget.event.amount} XP',
                      style: TextStyle(
                        color: sphere.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        decoration: TextDecoration.none,
                        letterSpacing: 0.5,
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

  static IconData _sphereIcon(XpSphere sphere) => switch (sphere) {
    XpSphere.willpower => Icons.bolt_rounded,
    XpSphere.intellect => Icons.auto_awesome_rounded,
    XpSphere.health    => Icons.favorite_rounded,
  };
}

// ─── LEVEL-UP SHEET ──────────────────────────────────────────────────────
class _LevelUpSheet extends StatefulWidget {
  final XpEvent event;
  const _LevelUpSheet({required this.event});

  @override
  State<_LevelUpSheet> createState() => _LevelUpSheetState();
}

class _LevelUpSheetState extends State<_LevelUpSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _barProgress;
  late Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barProgress = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _scaleIn = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sphere = widget.event.sphere;
    final level = widget.event.newLevel;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: BorderRadius.circular(28),
        border:
        Border.all(color: sphere.color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: sphere.color.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accent dot
          Container(
            width: 6,
            height: 6,
            decoration:
            BoxDecoration(color: sphere.color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 20),

          // Big sphere icon with scale-in animation
          AnimatedBuilder(
            animation: _scaleIn,
            builder: (_, __) => Transform.scale(
              scale: _scaleIn.value,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sphere.color.withValues(alpha: 0.12),
                  border: Border.all(
                    color: sphere.color.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: sphere.color.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  _sphereIcon(sphere),
                  size: 40,
                  color: sphere.color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // LEVEL UP badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: sphere.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'LEVEL UP!',
              style: TextStyle(
                color: sphere.color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            '${sphere.label} Level $level',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep going — Level ${level + 1} awaits.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Animated XP bar filling up
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: AnimatedBuilder(
              animation: _barProgress,
              builder: (_, __) => LinearProgressIndicator(
                value: _barProgress.value,
                backgroundColor: sphere.color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(sphere.color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level $level unlocked',
            style: TextStyle(
              color: sphere.color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),

          // Dismiss button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: sphere.color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  "Let's go",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _sphereIcon(XpSphere sphere) => switch (sphere) {
    XpSphere.willpower => Icons.bolt_rounded,
    XpSphere.intellect => Icons.auto_awesome_rounded,
    XpSphere.health    => Icons.favorite_rounded,
  };
}