import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  static const signIn = '/sign-in';
  static const home = '/home';
  static const tasks = '/tasks';
  static const habits = '/habits';
  static const goals = '/goals';
  static const pomodoro = '/pomodoro';
  static const lifeBalance = '/life-balance';
  static const statistics = '/statistics';
  static const profile = '/profile';
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
      builder: (_, __) => const SignInScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: ARoutes.home,
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: ARoutes.tasks,
          builder: (_, __) => const TasksScreen(),
        ),
        GoRoute(
          path: ARoutes.habits,
          builder: (_, __) => const HabitsScreen(),
        ),
        GoRoute(
          path: ARoutes.goals,
          builder: (_, __) => const GoalsScreen(),
        ),
        GoRoute(
          path: ARoutes.pomodoro,
          builder: (_, __) => const PomodoroScreen(),
        ),
        GoRoute(
          path: ARoutes.lifeBalance,
          builder: (_, __) => const LifeBalanceScreen(),
        ),
        GoRoute(
          path: ARoutes.statistics,
          builder: (_, __) => const StatisticsScreen(),
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