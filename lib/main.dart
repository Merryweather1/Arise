import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/settings_service.dart';
import 'core/providers/app_providers.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  await NotificationService.instance.initialize(container: container);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  runApp(ProviderScope(parent: container, child: const AriseApp()));
}

class AriseApp extends ConsumerStatefulWidget {
  const AriseApp({super.key});
  @override
  ConsumerState<AriseApp> createState() => _AriseAppState();
}

class _AriseAppState extends ConsumerState<AriseApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // If we're in system mode, a brightness change should trigger a rebuild
    final mode = ref.read(themeModeProvider);
    if (mode == AppThemeMode.system) {
      setState(() {}); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final colorTheme = ref.watch(colorThemeProvider);
    
    // Apply dynamic colors
    final settings = ref.read(settingsServiceProvider);
    AColors.applyTheme(mode, settings.getPrimaryColorFor(colorTheme));

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: AColors.bg == const Color(0xFF0A0F0D) ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AColors.bgCard,
      systemNavigationBarIconBrightness: AColors.bg == const Color(0xFF0A0F0D) ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp.router(
      title: 'Arise',
      debugShowCheckedModeBanner: false,
      theme: ATheme.themeData, // We'll rename dark to themeData
      routerConfig: appRouter,
    );
  }
}