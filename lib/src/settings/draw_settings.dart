import 'package:flutter/foundation.dart';

/// The options the organiser can change, persisted between launches.
@immutable
class DrawSettings {
  const DrawSettings({
    this.title = defaultTitle,
    this.min = 1,
    this.max = 200,
    this.allowRepeats = false,
  });

  static const defaultTitle = 'Our Wedding';

  /// The largest ticket number the app supports (five digits).
  static const maxSupportedNumber = 99999;

  /// Event title shown above the reels, e.g. "William & Anna".
  final String title;

  /// Lowest ticket number that can be drawn.
  final int min;

  /// Highest ticket number that can be drawn.
  final int max;

  /// Whether a number may win more than once.
  final bool allowRepeats;

  int get rangeSize => max - min + 1;

  /// Number of reels: enough digits to show [max].
  int get digitCount => max.toString().length;

  bool get isValid => validateRange(min, max) == null;

  /// Zero-pads [number] to [digitCount] digits, e.g. 7 -> "007".
  String format(int number) => number.toString().padLeft(digitCount, '0');

  /// Returns a message explaining why [min]..[max] is not a usable range, or
  /// null when it is fine.
  static String? validateRange(int min, int max) {
    if (min < 0 || max < 0) return 'Numbers cannot be negative.';
    if (max > maxSupportedNumber) {
      return 'The largest supported number is $maxSupportedNumber.';
    }
    if (min > max) return '"To" must be at least $min.';
    return null;
  }

  DrawSettings copyWith({
    String? title,
    int? min,
    int? max,
    bool? allowRepeats,
  }) {
    return DrawSettings(
      title: title ?? this.title,
      min: min ?? this.min,
      max: max ?? this.max,
      allowRepeats: allowRepeats ?? this.allowRepeats,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DrawSettings &&
      other.title == title &&
      other.min == min &&
      other.max == max &&
      other.allowRepeats == allowRepeats;

  @override
  int get hashCode => Object.hash(title, min, max, allowRepeats);

  @override
  String toString() =>
      'DrawSettings(title: $title, min: $min, max: $max, '
      'allowRepeats: $allowRepeats)';
}
