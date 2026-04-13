import 'package:flutter/material.dart';

class AIconMapper {
  AIconMapper._();

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

  static IconData? resolve(String emoji) =>
      habitIcons[emoji] ?? goalIcons[emoji];

  static Widget iconWidget(
      String emoji, {
        double size = 22,
        Color? color,
      }) {
    final icon = resolve(emoji);
    if (icon != null) {
      return Icon(icon, size: size, color: color ?? Colors.white);
    }
    return Text(emoji, style: TextStyle(fontSize: size * 0.9));
  }
}
