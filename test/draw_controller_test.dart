import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wedding_draw/src/draw/draw_controller.dart';
import 'package:wedding_draw/src/settings/draw_settings.dart';
import 'package:wedding_draw/src/settings/draw_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<DrawController> createController([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    return DrawController(storage: DrawStorage(prefs), random: Random(1));
  }

  List<String>? savedWinners() => prefs.getStringList(DrawStorage.winnersKey);

  group('DrawController', () {
    test(
      'starts idle with the saved settings, winners and mute flag',
      () async {
        final controller = await createController({
          DrawStorage.titleKey: 'William & Anna',
          DrawStorage.maxKey: 50,
          DrawStorage.winnersKey: ['7', '12'],
          DrawStorage.mutedKey: true,
        });

        expect(controller.phase, DrawPhase.idle);
        expect(controller.settings.title, 'William & Anna');
        expect(controller.settings.max, 50);
        expect(controller.winners, [7, 12]);
        expect(controller.remainingCount, 48);
        expect(controller.muted, isTrue);
        expect(controller.canDraw, isTrue);
      },
    );

    test('records the winner only when the draw completes', () async {
      final controller = await createController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      final number = controller.startDraw();

      expect(controller.phase, DrawPhase.spinning);
      expect(controller.currentNumber, number);
      expect(controller.winners, isEmpty);
      expect(controller.canDraw, isFalse);
      expect(savedWinners(), isNull);

      controller.completeDraw();

      expect(controller.phase, DrawPhase.revealed);
      expect(controller.winners, [number]);
      expect(savedWinners(), ['$number']);
      expect(controller.canDraw, isTrue);
      expect(notifications, 2);

      controller.completeDraw(); // A second call must not record it again.
      expect(controller.winners, [number]);
    });

    test('cannot start a draw while spinning', () async {
      final controller = await createController();
      controller.startDraw();

      expect(controller.startDraw, throwsStateError);
    });

    test('reset discards a number that was still spinning', () async {
      final controller = await createController();
      controller.startDraw();

      controller.reset();

      expect(controller.phase, DrawPhase.idle);
      expect(controller.currentNumber, isNull);
      controller.completeDraw();
      expect(controller.winners, isEmpty);
    });

    test('can draw again straight from a reveal, without repeats', () async {
      final controller = await createController({
        DrawStorage.minKey: 1,
        DrawStorage.maxKey: 2,
      });

      controller
        ..startDraw()
        ..completeDraw()
        ..startDraw()
        ..completeDraw();

      expect(controller.winners.toSet(), {1, 2});
      expect(controller.isExhausted, isTrue);
      expect(controller.canDraw, isFalse);
      expect(controller.startDraw, throwsStateError);
    });

    test('changing the range keeps the history', () async {
      final controller = await createController({
        DrawStorage.winnersKey: ['5', '150'],
      });

      controller.updateSettings(const DrawSettings(min: 1, max: 100));

      expect(controller.winners, [5, 150]);
      expect(controller.isInRange(150), isFalse);
      expect(controller.remainingCount, 99);
      expect(prefs.getInt(DrawStorage.maxKey), 100);
    });

    test(
      'a range change clears the revealed number, a title change does not',
      () async {
        final controller = await createController();
        controller
          ..startDraw()
          ..completeDraw();

        controller.updateSettings(controller.settings.copyWith(title: 'Hi'));
        expect(controller.phase, DrawPhase.revealed);
        expect(prefs.getString(DrawStorage.titleKey), 'Hi');

        controller.updateSettings(controller.settings.copyWith(max: 500));
        expect(controller.phase, DrawPhase.idle);
        expect(controller.currentNumber, isNull);
        expect(controller.winners, hasLength(1));
      },
    );

    test('rejects invalid settings and changes while spinning', () async {
      final controller = await createController();

      expect(
        () => controller.updateSettings(const DrawSettings(min: 9, max: 3)),
        throwsArgumentError,
      );

      controller.startDraw();
      expect(
        () => controller.updateSettings(const DrawSettings(max: 20)),
        throwsStateError,
      );
      expect(() => controller.removeWinnerAt(0), throwsStateError);
      expect(controller.clearWinners, throwsStateError);
      expect(controller.settings, const DrawSettings());
    });

    test('undo, remove, restore and clear are saved', () async {
      final controller = await createController({
        DrawStorage.winnersKey: ['3', '6', '9'],
      });

      expect(controller.undoLastWinner(), 9);
      expect(savedWinners(), ['3', '6']);

      expect(controller.removeWinnerAt(0), 3);
      expect(savedWinners(), ['6']);

      expect(controller.restoreWinner(0, 3), isTrue);
      expect(controller.winners, [3, 6]);
      expect(savedWinners(), ['3', '6']);
      expect(controller.restoreWinner(0, 6), isFalse);

      controller.clearWinners();
      expect(controller.winners, isEmpty);
      expect(savedWinners(), isEmpty);
      expect(controller.undoLastWinner(), isNull);
    });

    test('saves the mute flag', () async {
      final controller = await createController();

      controller.setMuted(true);

      expect(controller.muted, isTrue);
      expect(prefs.getBool(DrawStorage.mutedKey), isTrue);
    });
  });
}
