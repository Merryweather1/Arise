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
  static       final _tabs = [
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

    ref.watch(themeModeProvider);
    ref.watch(colorThemeProvider);

    ref.watch(notificationBootProvider);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != 0) context.go(ARoutes.home);
      },
      child: Scaffold(
        backgroundColor: AColors.bg,
        extendBody: true,
        body: widget.child,
        bottomNavigationBar: _GlassPillNavBar(
          currentIndex: currentIndex,
          icons: _icons,
          onTap: (i) {
            HapticFeedback.selectionClick();
            context.go(_tabs[i]);
          },
        ),
      ),
    );
  }
}

class _GlassPillNavBar extends StatefulWidget {
  final int currentIndex;
  final List<IconData> icons;
  final ValueChanged<int> onTap;

  const _GlassPillNavBar({
    required this.currentIndex,
    required this.icons,
    required this.onTap,
  });

  @override
  State<_GlassPillNavBar> createState() => _GlassPillNavBarState();
}

class _GlassPillNavBarState extends State<_GlassPillNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _position = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_GlassPillNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      final from = old.currentIndex.toDouble();
      final to = widget.currentIndex.toDouble();
      _position = Tween<double>(begin: from, end: to)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final count = widget.icons.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(40, 0, 40, bottom > 0 ? bottom : 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AColors.bgSleek.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: AColors.borderSleek.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final slotWidth = totalWidth / count;
                const pad = 7.0;

                return AnimatedBuilder(
                  animation: _position,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: _position.value * slotWidth + pad,
                        child: Container(
                          width: slotWidth - pad * 2,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AColors.primary.withValues(alpha: 0.28),
                                AColors.primary.withValues(alpha: 0.06),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: AColors.primary.withValues(alpha: 0.22),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(count, (i) {
                          final selected = i == widget.currentIndex;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onTap(i),
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                height: 64,
                                child: Center(
                                  child: AnimatedScale(
                                    scale: selected ? 1.12 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedTheme(
                                      data: Theme.of(context),
                                      duration: const Duration(milliseconds: 250),
                                      child: Icon(
                                        widget.icons[i],
                                        size: 24,
                                        color: selected
                                            ? AColors.primary
                                            : AColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

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
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _slide.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Center(
              child: Material(
                color: Colors.transparent,
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
                      Icon(sphere.icon, size: 18, color: sphere.color),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.event.amount} XP',
                        style: TextStyle(
                          color: sphere.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
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
          Container(
            width: 6,
            height: 6,
            decoration:
            BoxDecoration(color: sphere.color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 20),

          AnimatedBuilder(
            animation: _scaleIn,
            builder: (context, child) => Transform.scale(
              scale: _scaleIn.value,
              child: Icon(sphere.icon, size: 64, color: sphere.color),
            ),
          ),
          const SizedBox(height: 16),

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

          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: AnimatedBuilder(
              animation: _barProgress,
              builder: (context, child) => LinearProgressIndicator(
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
                  "Let's go! 🔥",
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
}
