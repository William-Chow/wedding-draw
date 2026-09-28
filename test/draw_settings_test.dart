import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_draw/src/settings/draw_settings.dart';

void main() {
  group('DrawSettings', () {
    test('defaults to numbers 1 to 200 without repeats', () {
      const settings = DrawSettings();

      expect(settings.min, 1);
      expect(settings.max, 200);
      expect(settings.allowRepeats, isFalse);
      expect(settings.rangeSize, 200);
      expect(settings.isValid, isTrue);
    });

    test('derives the digit count from the maximum and zero-pads', () {
      expect(const DrawSettings(max: 9).digitCount, 1);
      expect(const DrawSettings(max: 200).format(7), '007');
      expect(const DrawSettings(max: 200).format(150), '150');
      expect(const DrawSettings(max: 1000).format(42), '0042');
      expect(const DrawSettings(max: 99999).format(42), '00042');
    });

    test('validates the range', () {
      expect(DrawSettings.validateRange(1, 200), isNull);
      expect(DrawSettings.validateRange(5, 5), isNull);
      expect(DrawSettings.validateRange(0, 99999), isNull);
      expect(DrawSettings.validateRange(10, 9), '"To" must be at least 10.');
      expect(DrawSettings.validateRange(1, 100000), contains('99999'));
      expect(DrawSettings.validateRange(-1, 10), isNotNull);
      expect(const DrawSettings(min: 3, max: 2).isValid, isFalse);
    });

    test('supports copyWith and value equality', () {
      const settings = DrawSettings(title: 'William & Anna');

      final copy = settings.copyWith(max: 300, allowRepeats: true);

      expect(copy.title, 'William & Anna');
      expect(copy.max, 300);
      expect(copy.allowRepeats, isTrue);
      expect(settings.copyWith(), settings);
      expect(settings.copyWith().hashCode, settings.hashCode);
      expect(copy, isNot(settings));
    });
  });
}
