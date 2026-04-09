import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }
enum AppColorTheme { emerald, ruby, amethyst, sapphire, amber }

class SettingsService {
  static const _themeModeKey = 'theme_mode_v1';
  static const _colorThemeKey = 'color_theme_v1';
  
  final SharedPreferences _prefs;
  
  SettingsService(this._prefs);
  
  // Theme Mode
  AppThemeMode getThemeMode() {
    final val = _prefs.getString(_themeModeKey);
    if (val == AppThemeMode.light.name) return AppThemeMode.light;
    if (val == AppThemeMode.dark.name) return AppThemeMode.dark;
    return AppThemeMode.system;
  }
  
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }
  
  // Color Theme
  AppColorTheme getColorTheme() {
    final val = _prefs.getString(_colorThemeKey);
    if (val == AppColorTheme.ruby.name) return AppColorTheme.ruby;
    if (val == AppColorTheme.amethyst.name) return AppColorTheme.amethyst;
    if (val == AppColorTheme.sapphire.name) return AppColorTheme.sapphire;
    if (val == AppColorTheme.amber.name) return AppColorTheme.amber;
    return AppColorTheme.emerald; // Default
  }
  
  Future<void> setColorTheme(AppColorTheme theme) async {
    await _prefs.setString(_colorThemeKey, theme.name);
  }
  
  Color getPrimaryColorFor(AppColorTheme theme) {
    switch (theme) {
      case AppColorTheme.ruby:
        return const Color(0xFFE53E3E);
      case AppColorTheme.amethyst:
        return const Color(0xFF9F7AEA);
      case AppColorTheme.sapphire:
        return const Color(0xFF3182CE);
      case AppColorTheme.amber:
        return const Color(0xFFD69E2E);
      case AppColorTheme.emerald:
      default:
        return const Color(0xFF00C97B); // Original Emerald
    }
  }
}
