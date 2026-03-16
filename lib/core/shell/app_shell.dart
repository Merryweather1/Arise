import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../router/app_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

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

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (currentIndex != 0) {
          context.go(ARoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AColors.bg,
        body: child,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AColors.bgCard,
            border: Border(top: BorderSide(color: AColors.border)),
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
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AColors.primaryGlow
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
                              fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AColors.primary
                                  : AColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}