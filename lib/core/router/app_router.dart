import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/sign_in_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/life_balance/life_balance_screen.dart';
import '../../features/pomodoro/pomodoro_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/statistics/statistics_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../shell/app_shell.dart';

class ARoutes {
  static const String signIn = '/sign-in';
  static const String home = '/home';
  static const String tasks = '/tasks';
  static const String habits = '/habits';
  static const String goals = '/goals';
  static const String pomodoro = '/pomodoro';
  static const String lifeBalance = '/life-balance';
  static const String statistics = '/statistics';
  static const String profile = '/profile';
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _routerRefresh =
GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges());

/// Smooth fade + subtle upward slide — Apple-style tab transition.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration:       Duration(milliseconds: 260),
    reverseTransitionDuration:       Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin:       Offset(0, 0.04),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}


final appRouter = GoRouter(
  initialLocation: ARoutes.home,
  refreshListenable: _routerRefresh,
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final onSignIn = state.matchedLocation == ARoutes.signIn;

    if (!loggedIn) {
      return onSignIn ? null : ARoutes.signIn;
    }

    if (loggedIn && onSignIn) {
      return ARoutes.home;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: ARoutes.signIn,
      builder: (_, __) =>       SignInScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: ARoutes.home,
          pageBuilder: (_, s) => _fadePage(s,       HomeScreen()),
        ),
        GoRoute(
          path: ARoutes.tasks,
          pageBuilder: (_, s) => _fadePage(s,       TasksScreen()),
        ),
        GoRoute(
          path: ARoutes.habits,
          pageBuilder: (_, s) => _fadePage(s,       HabitsScreen()),
        ),
        GoRoute(
          path: ARoutes.goals,
          pageBuilder: (_, s) => _fadePage(s,       GoalsScreen()),
        ),
        GoRoute(
          path: ARoutes.pomodoro,
          pageBuilder: (_, s) => _fadePage(s,       PomodoroScreen()),
        ),
        GoRoute(
          path: ARoutes.lifeBalance,
          pageBuilder: (_, s) => _fadePage(s,       LifeBalanceScreen()),
        ),
        GoRoute(
          path: ARoutes.statistics,
          pageBuilder: (_, s) => _fadePage(s, const StatisticsScreen()),
        ),
      ],
    ),
    // Full-screen profile — outside shell so nav bar is hidden
    GoRoute(
      path: ARoutes.profile,
      pageBuilder: (_, __) => const MaterialPage(child: ProfileScreen()),
    ),
  ],
);