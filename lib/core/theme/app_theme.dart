import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── COLORS ───────────────────────────────────────────────────────────────
class AColors {
  AColors._();

  static const primary       = Color(0xFF00C97B);
  static const primaryDark   = Color(0xFF00A362);
  static const primaryGlow   = Color(0x2200C97B);

  static const bg            = Color(0xFF0A0F0D);
  static const bgCard        = Color(0xFF131A16);
  static const bgElevated    = Color(0xFF1A2420);
  static const bgInput       = Color(0xFF1F2B26);
  
  static const bgSleek       = Color(0xFF0D1210);
  static const borderSleek   = Color(0xFF18221D);

  static const border        = Color(0xFF243029);

  static const textPrimary   = Color(0xFFF0FAF5);
  static const textSecondary = Color(0xFF8BA898);
  static const textMuted     = Color(0xFF4D6359);

  static const warning       = Color(0xFFFFB547);
  static const error         = Color(0xFFFF5C5C);
  static const info          = Color(0xFF5B9CF6);

  static const priority1     = Color(0xFFFF5C5C);
  static const priority2     = Color(0xFFFFB547);
  static const priority3     = Color(0xFF5B9CF6);
  static const priority4     = Color(0xFF8BA898);

  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF00C97B), Color(0xFF00A362)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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

  static const displayLarge  = TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AColors.textPrimary, letterSpacing: -1.0);
  static const displayMedium = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AColors.textPrimary, letterSpacing: -0.8);
  static const titleLarge    = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AColors.textPrimary, letterSpacing: -0.5);
  static const titleMedium   = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AColors.textPrimary, letterSpacing: -0.4);
  static const titleSmall    = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AColors.textPrimary, letterSpacing: -0.3);
  static const bodyLarge     = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AColors.textPrimary);
  static const bodyMedium    = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AColors.textSecondary);
  static const bodySmall     = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AColors.textMuted);
  static const labelLarge    = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AColors.textPrimary);
  static const labelSmall    = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AColors.textMuted, letterSpacing: 0.5);
}

// ─── THEME ────────────────────────────────────────────────────────────────
class ATheme {
  ATheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AColors.bg,

    colorScheme: const ColorScheme.dark(
      primary:      AColors.primary,
      onPrimary:    Color(0xFF003D25),
      secondary:    AColors.primaryDark,
      surface:      AColors.bgCard,
      onSurface:    AColors.textPrimary,
      error:        AColors.error,
      outline:      AColors.border,
    ),

    appBarTheme: const AppBarTheme(
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
        side: const BorderSide(color: AColors.border),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AColors.bgInput,
      hintStyle: AText.bodyMedium,
      border: OutlineInputBorder(borderRadius: ARadius.md, borderSide: const BorderSide(color: AColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: ARadius.md, borderSide: const BorderSide(color: AColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: ARadius.md, borderSide: const BorderSide(color: AColors.primary, width: 1.5)),
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

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AColors.primary,
      foregroundColor: Color(0xFF003D25),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: ARadius.xl),
    ),

    dividerTheme: const DividerThemeData(color: AColors.border, thickness: 1, space: 1),

    dialogTheme: DialogThemeData(
      backgroundColor: AColors.bgElevated,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: ARadius.xl),
      titleTextStyle: AText.titleMedium,
      contentTextStyle: AText.bodyMedium,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
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
      side: const BorderSide(color: AColors.border, width: 1.5),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AColors.primary : AColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AColors.primaryGlow : AColors.bgInput),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AColors.primary,
      linearTrackColor: AColors.border,
    ),

    sliderTheme: const SliderThemeData(
      activeTrackColor: AColors.primary,
      inactiveTrackColor: AColors.border,
      thumbColor: AColors.primary,
      trackHeight: 4,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AColors.bgElevated,
      labelStyle: AText.bodySmall,
      shape: const RoundedRectangleBorder(borderRadius: ARadius.full),
      side: const BorderSide(color: AColors.border),
    ),

    textTheme: const TextTheme(
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
