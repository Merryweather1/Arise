import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

// ─── COLORS ───────────────────────────────────────────────────────────────
class AColors {
  AColors._();

  static Color primary       = const Color(0xFF00C97B);
  static Color primaryDark   = const Color(0xFF00A362);
  static Color primaryGlow   = const Color(0x2200C97B);

  static Color bg            = const Color(0xFF0A0F0D);
  static Color bgCard        = const Color(0xFF131A16);
  static Color bgElevated    = const Color(0xFF1A2420);
  static Color bgInput       = const Color(0xFF1F2B26);

  static Color bgSleek       = const Color(0xFF0D1210);
  static Color borderSleek   = const Color(0xFF18221D);

  static Color border        = const Color(0xFF243029);

  static Color textPrimary   = const Color(0xFFF0FAF5);
  static Color textSecondary = const Color(0xFF8BA898);
  static Color textMuted     = const Color(0xFF4D6359);

  static Color warning       = const Color(0xFFFFB547);
  static Color error         = const Color(0xFFFF5C5C);
  static Color info          = const Color(0xFF5B9CF6);

  static Color priority1     = const Color(0xFFFF5C5C);
  static Color priority2     = const Color(0xFFFFB547);
  static Color priority3     = const Color(0xFF5B9CF6);
  static Color priority4     = const Color(0xFF8BA898);

  static LinearGradient gradientPrimary = const LinearGradient(
    colors: [Color(0xFF00C97B), Color(0xFF00A362)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static void applyTheme(AppThemeMode mode, Color primaryColor) {
    bool isLight = mode == AppThemeMode.light ||
        (mode == AppThemeMode.system && PlatformDispatcher.instance.platformBrightness == Brightness.light);

    if (isLight) {
      bg = const Color(0xFFF7F9FC);
      bgCard = const Color(0xFFFFFFFF);
      bgElevated = const Color(0xFFFFFFFF);
      bgInput = const Color(0xFFEDF2F7);
      bgSleek = const Color(0xFFFFFFFF);
      borderSleek = const Color(0xFFE2E8F0);
      border = const Color(0xFFE2E8F0);
      textPrimary = const Color(0xFF1A202C);
      textSecondary = const Color(0xFF4A5568);
      textMuted = const Color(0xFFA0AEC0);
    } else {
      bg = const Color(0xFF0A0F0D);
      bgCard = const Color(0xFF131A16);
      bgElevated = const Color(0xFF1A2420);
      bgInput = const Color(0xFF1F2B26);
      bgSleek = const Color(0xFF0D1210);
      borderSleek = const Color(0xFF18221D);
      border = const Color(0xFF243029);
      textPrimary = const Color(0xFFF0FAF5);
      textSecondary = const Color(0xFF8BA898);
      textMuted = const Color(0xFF4D6359);
    }

    final hsl = HSLColor.fromColor(primaryColor);
    final darkHsl = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0));
    primary = primaryColor;
    primaryDark = darkHsl.toColor();
    primaryGlow = primaryColor.withValues(alpha: 0.15);

    gradientPrimary = LinearGradient(
      colors: [primary, primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

// ─── SPACING & RADIUS ─────────────────────────────────────────────────────
class ARadius {
  ARadius._();
  static const sm   = BorderRadius.all(Radius.circular(8));
  static const md   = BorderRadius.all(Radius.circular(12));
  static const lg   = BorderRadius.all(Radius.circular(16));
  static const xl   = BorderRadius.all(Radius.circular(20));
  static const xxl  = BorderRadius.all(Radius.circular(28));
  static const full = BorderRadius.all(Radius.circular(999));
}

// ─── TEXT STYLES ──────────────────────────────────────────────────────────
class AText {
  AText._();

  static TextStyle get displayLarge  => TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AColors.textPrimary, letterSpacing: -1.0);
  static TextStyle get displayMedium => TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AColors.textPrimary, letterSpacing: -0.8);
  static TextStyle get titleLarge    => TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AColors.textPrimary, letterSpacing: -0.5);
  static TextStyle get titleMedium   => TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AColors.textPrimary, letterSpacing: -0.4);
  static TextStyle get titleSmall    => TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AColors.textPrimary, letterSpacing: -0.3);
  static TextStyle get bodyLarge     => TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AColors.textPrimary);
  static TextStyle get bodyMedium    => TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AColors.textSecondary);
  static TextStyle get bodySmall     => TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AColors.textMuted);
  static TextStyle get labelLarge    => TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AColors.textPrimary);
  static TextStyle get labelSmall    => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AColors.textMuted, letterSpacing: 0.5);
}

// ─── THEME ────────────────────────────────────────────────────────────────
class ATheme {
  ATheme._();

  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: AColors.bg == const Color(0xFF0A0F0D) ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AColors.bg,

    colorScheme: AColors.bg == const Color(0xFF0A0F0D) ? ColorScheme.dark(
      primary:      AColors.primary,
      onPrimary:    const Color(0xFF003D25),
      secondary:    AColors.primaryDark,
      surface:      AColors.bgCard,
      onSurface:    AColors.textPrimary,
      error:        AColors.error,
      outline:      AColors.border,
    ) : ColorScheme.light(
      primary:      AColors.primary,
      onPrimary:    const Color(0xFFFFFFFF),
      secondary:    AColors.primaryDark,
      surface:      AColors.bgCard,
      onSurface:    AColors.textPrimary,
      error:        AColors.error,
      outline:      AColors.border,
    ),

    appBarTheme:       AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AColors.bgCard,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: AText.titleMedium,
      iconTheme: IconThemeData(color: AColors.textPrimary),
    ),

    cardTheme: CardThemeData(
      color: AColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: ARadius.lg,
        side: BorderSide(color: AColors.border),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AColors.bgInput,
      hintStyle: AText.bodyMedium,
      border: OutlineInputBorder(borderRadius: ARadius.md, borderSide: BorderSide(color: AColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: ARadius.md, borderSide: BorderSide(color: AColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: ARadius.md, borderSide: BorderSide(color: AColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AColors.primary,
        foregroundColor: const Color(0xFF003D25),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: ARadius.md),
        textStyle: AText.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(0, 50),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AColors.primary,
        textStyle: AText.labelLarge,
      ),
    ),

    floatingActionButtonTheme:       FloatingActionButtonThemeData(
      backgroundColor: AColors.primary,
      foregroundColor: Color(0xFF003D25),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: ARadius.xl),
    ),

    dividerTheme: DividerThemeData(color: AColors.border, thickness: 1, space: 1),

    dialogTheme: DialogThemeData(
      backgroundColor: AColors.bgElevated,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: ARadius.xl),
      titleTextStyle: AText.titleMedium,
      contentTextStyle: AText.bodyMedium,
    ),

    bottomSheetTheme:       BottomSheetThemeData(
      backgroundColor: AColors.bgElevated,
      modalBackgroundColor: AColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
      states.contains(WidgetState.selected) ? AColors.primary : Colors.transparent),
      checkColor: WidgetStateProperty.all(const Color(0xFF003D25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: BorderSide(color: AColors.border, width: 1.5),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
      states.contains(WidgetState.selected) ? AColors.primary : AColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
      states.contains(WidgetState.selected) ? AColors.primaryGlow : AColors.bgInput),
    ),

    progressIndicatorTheme:       ProgressIndicatorThemeData(
      color: AColors.primary,
      linearTrackColor: AColors.border,
    ),

    sliderTheme:       SliderThemeData(
      activeTrackColor: AColors.primary,
      inactiveTrackColor: AColors.border,
      thumbColor: AColors.primary,
      trackHeight: 4,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AColors.bgElevated,
      labelStyle: AText.bodySmall,
      shape: const RoundedRectangleBorder(borderRadius: ARadius.full),
      side: BorderSide(color: AColors.border),
    ),

    textTheme:       TextTheme(
      displayLarge:  AText.displayLarge,
      displayMedium: AText.displayMedium,
      titleLarge:    AText.titleLarge,
      titleMedium:   AText.titleMedium,
      titleSmall:    AText.titleSmall,
      bodyLarge:     AText.bodyLarge,
      bodyMedium:    AText.bodyMedium,
      bodySmall:     AText.bodySmall,
      labelLarge:    AText.labelLarge,
      labelSmall:    AText.labelSmall,
    ),
  );
}