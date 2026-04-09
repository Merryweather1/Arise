import 'package:flutter/material.dart';

/// Maps legacy emoji strings to modern, clean Material Icons.
/// Used across habit / goal editors & display cards.
class AIconMapper {
  AIconMapper._();

  // ─── HABITS ────────────────────────────────────────────────────────────
  static const habitIcons = <String, IconData>{
    '🧘': Icons.self_improvement_rounded,
    '📚': Icons.menu_book_rounded,
    '💪': Icons.fitness_center_rounded,
    '📝': Icons.edit_note_rounded,
    '🚿': Icons.shower_rounded,
    '🍎': Icons.apple_rounded,
    '💧': Icons.water_drop_rounded,
    '🏃': Icons.directions_run_rounded,
    '🎯': Icons.track_changes_rounded,
    '🛌': Icons.bed_rounded,
    '🧠': Icons.psychology_rounded,
    '🎸': Icons.music_note_rounded,
    '🌱': Icons.eco_rounded,
    '🚴': Icons.pedal_bike_rounded,
    '🍵': Icons.local_cafe_rounded,
  };

  // ─── GOALS ─────────────────────────────────────────────────────────────
  static const goalIcons = <String, IconData>{
    '🎯': Icons.track_changes_rounded,
    '📱': Icons.phone_iphone_rounded,
    '🏃': Icons.directions_run_rounded,
    '💰': Icons.savings_rounded,
    '📚': Icons.menu_book_rounded,
    '💪': Icons.fitness_center_rounded,
    '🚀': Icons.rocket_launch_rounded,
    '🎸': Icons.music_note_rounded,
    '✈️': Icons.flight_rounded,
    '🏠': Icons.home_rounded,
    '🎓': Icons.school_rounded,
    '💼': Icons.work_rounded,
    '🌍': Icons.public_rounded,
    '🏆': Icons.emoji_events_rounded,
    '❤️': Icons.favorite_rounded,
  };

  /// Resolve an emoji to an IconData without falling back to text.
  static IconData? resolve(String emoji) =>
      habitIcons[emoji] ?? goalIcons[emoji];

  /// Get an Icon widget with current-selection styling.
  static Widget iconWidget(
      String emoji, {
        double size = 22,
        Color? color,
      }) {
    final icon = resolve(emoji);
    if (icon != null) {
      return Icon(icon, size: size, color: color ?? Colors.white);
    }
    // Fallback: render raw string for any unknown emoji
    return Text(emoji, style: TextStyle(fontSize: size * 0.9));
  }
}
