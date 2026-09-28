import 'package:flutter/material.dart';

/// Rose and champagne colours shared by the theme and the custom widgets.
abstract final class WeddingPalette {
  /// Seed colour of the Material colour scheme.
  static const rose = Color(0xFFB4436C);

  /// Headings and drawn numbers (7:1 contrast on [ivory]).
  static const roseDeep = Color(0xFF8A2C4F);

  static const blush = Color(0xFFF9E3E7);
  static const ivory = Color(0xFFFFFAF6);
  static const champagne = Color(0xFFF4E6CC);

  /// Borders and ornaments.
  static const gold = Color(0xFFC9A45C);

  /// Gold for text, dark enough for readable contrast on light backgrounds.
  static const goldText = Color(0xFF7E5F24);

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFCF8), Color(0xFFFBE7E6)],
  );

  static const confetti = [
    rose,
    Color(0xFFF2A7BB),
    gold,
    Color(0xFFFFF0D2),
    Color(0xFFE9C3A2),
    Colors.white,
  ];
}
