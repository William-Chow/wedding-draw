import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_draw/src/draw/winners_text.dart';
import 'package:wedding_draw/src/settings/draw_settings.dart';

void main() {
  const settings = DrawSettings(title: 'William & Anna', min: 1, max: 200);

  String text(List<int> winners, {String title = 'William & Anna'}) =>
      winnersAsText(
        title: title,
        winners: winners,
        format: settings.format,
        isInRange: (n) => n >= settings.min && n <= settings.max,
      );

  test('lists the winners in draw order, padded like the reels', () {
    expect(
      text([7, 153, 42]),
      'William & Anna – lucky draw winners\n'
      '#1  007\n'
      '#2  153\n'
      '#3  042',
    );
  });

  test('marks winners outside the current range', () {
    expect(
      text([250, 3]),
      'William & Anna – lucky draw winners\n'
      '#1  250  (outside the current range)\n'
      '#2  003',
    );
  });

  test('falls back to a plain heading without a title', () {
    expect(text([1], title: '   '), 'Lucky draw winners\n#1  001');
  });
}
