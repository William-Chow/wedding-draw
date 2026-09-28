import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wedding_draw/src/draw/draw_controller.dart';
import 'package:wedding_draw/src/draw/draw_pool.dart';
import 'package:wedding_draw/src/settings/draw_settings.dart';
import 'package:wedding_draw/src/settings/draw_storage.dart';
import 'package:wedding_draw/src/ui/history_panel.dart';
import 'package:wedding_draw/src/ui/reel_spin.dart';

import 'test_helpers.dart';

/// The first number the app will draw from 1–200 with [testSeed].
final firstWinner = DrawPool(min: 1, max: 200, random: Random(testSeed)).pick();
final firstWinnerLabel = '$firstWinner'.padLeft(3, '0');

Finder inHistory(String text) =>
    find.descendant(of: find.byType(HistoryPanel), matching: find.text(text));

/// Pumps through the whole reveal: all reels stopped, winner announced.
Future<void> pumpThroughSpin(WidgetTester tester) async {
  await tester.pump(SpinTiming.lastReelStop);
  await tester.pump();
}

Future<void> tapDraw(WidgetTester tester) async {
  await tester.tap(drawButtonFinder);
  await tester.pump();
}

void main() {
  testWidgets('shows an idle draw ready to start', (tester) async {
    await pumpDrawApp(tester);

    expect(find.text(DrawSettings.defaultTitle), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(drawButton(tester).onPressed, isNotNull);
    expect(reelDigits(tester), '???');
    expect(find.text('200 of 200 numbers left'), findsOneWidget);
    expect(find.textContaining('No winners yet'), findsOneWidget);
    expect(resetButtonFinder, findsNothing);
  });

  testWidgets('reveals and records the winner only after the last reel stops', (
    tester,
  ) async {
    final sounds = RecordingSoundEffects();
    final controller = await pumpDrawApp(tester, sounds: sounds);

    await tapDraw(tester);

    // Spinning: the button is disabled and nothing is announced yet.
    expect(controller.phase, DrawPhase.spinning);
    expect(drawButton(tester).onPressed, isNull);
    expect(find.text('Drawing…'), findsOneWidget);
    expect(sounds.calls, ['startSpin']);

    // An accidental second tap does not cancel the draw.
    await tester.tap(drawButtonFinder);
    await tester.pump();
    expect(controller.phase, DrawPhase.spinning);

    // The first reel stops at 3 s; the winner is still secret.
    await tester.pump(SpinTiming.firstReelStop);
    expect(sounds.count('reelStopped'), 1);
    expect(controller.winners, isEmpty);
    expect(find.text('#1'), findsNothing);
    expect(inHistory(firstWinnerLabel), findsNothing);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(sounds.count('reelStopped'), 2);
    expect(controller.winners, isEmpty);
    expect(sounds.count('reveal'), 0);

    // The last reel stops at 6 s: now the winner is shown and saved, once.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(controller.phase, DrawPhase.revealed);
    expect(sounds.count('reelStopped'), 3);
    expect(sounds.calls.last, 'reveal');
    expect(reelDigits(tester), firstWinnerLabel);
    expect(controller.winners, [firstWinner]);
    expect(inHistory(firstWinnerLabel), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsNothing);
    expect(find.text('Winner #1'), findsOneWidget);
    expect(find.text('Draw again'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(DrawStorage.winnersKey), ['$firstWinner']);

    // Later frames do not record it again.
    await tester.pump(const Duration(seconds: 5));
    expect(controller.winners, [firstWinner]);

    // Reset returns to idle and keeps the history.
    await tester.tap(resetButtonFinder);
    await tester.pump();
    expect(controller.phase, DrawPhase.idle);
    expect(reelDigits(tester), '???');
    expect(resetButtonFinder, findsNothing);
    expect(drawButton(tester).onPressed, isNotNull);
    expect(inHistory(firstWinnerLabel), findsOneWidget);
    expect(find.text('199 of 200 numbers left'), findsOneWidget);
    expect(sounds.calls.last, 'stop');
  });

  testWidgets('Draw again starts the next draw without repeating a number', (
    tester,
  ) async {
    final controller = await pumpDrawApp(tester);

    await tapDraw(tester);
    await pumpThroughSpin(tester);
    await tester.tap(find.text('Draw again'));
    await tester.pump();

    expect(controller.phase, DrawPhase.spinning);
    expect(controller.winners, [firstWinner]);

    await pumpThroughSpin(tester);
    expect(controller.winners, hasLength(2));
    expect(controller.winners.toSet(), hasLength(2));
    expect(find.text('#2'), findsOneWidget);
  });

  testWidgets('keyboard: Space draws when idle, Escape resets after a reveal', (
    tester,
  ) async {
    final controller = await pumpDrawApp(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.phase, DrawPhase.spinning);

    // Keys pressed mid-spin are ignored.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.phase, DrawPhase.spinning);

    await pumpThroughSpin(tester);
    expect(controller.phase, DrawPhase.revealed);

    // A stray clicker press after the reveal does not start a new draw.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.phase, DrawPhase.revealed);
    expect(controller.winners, hasLength(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.phase, DrawPhase.idle);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.phase, DrawPhase.spinning);
    await pumpThroughSpin(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.phase, DrawPhase.idle);
    expect(controller.winners, hasLength(2));
  });

  testWidgets('Undo last takes back the newest winner, with undo', (
    tester,
  ) async {
    final controller = await pumpDrawApp(tester);
    await tapDraw(tester);
    await pumpThroughSpin(tester);

    await tester.tap(find.byTooltip('Undo last draw'));
    await tester.pump();

    expect(controller.winners, isEmpty);
    expect(controller.phase, DrawPhase.idle, reason: 'it was on screen');
    expect(inHistory(firstWinnerLabel), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(DrawStorage.winnersKey), isEmpty);

    await tester.pump(const Duration(seconds: 1)); // Snack bar slides in.
    expect(find.textContaining('Took back winner #1'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(controller.winners, [firstWinner]);
    expect(inHistory(firstWinnerLabel), findsOneWidget);
  });

  testWidgets('removes a single winner, with undo', (tester) async {
    final controller = await pumpDrawApp(
      tester,
      prefs: {
        DrawStorage.winnersKey: ['5', '17', '42'],
      },
    );
    expect(inHistory('017'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove winner #2'));
    await tester.pump();

    expect(controller.winners, [5, 42]);
    expect(inHistory('017'), findsNothing);
    expect(find.text('#3'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(controller.winners, [5, 17, 42]);
  });

  testWidgets('Clear all asks for confirmation first', (tester) async {
    final controller = await pumpDrawApp(
      tester,
      prefs: {
        DrawStorage.winnersKey: ['5', '17', '42'],
      },
    );

    await tester.tap(find.byTooltip('Clear all winners'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all winners?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.winners, [5, 17, 42]);

    await tester.tap(find.byTooltip('Clear all winners'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmClearAllButton')));
    await tester.pumpAndSettle();

    expect(controller.winners, isEmpty);
    expect(find.textContaining('No winners yet'), findsOneWidget);
    expect(
      find.text('All winners cleared. Every number can be drawn again.'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(DrawStorage.winnersKey), isEmpty);
  });

  testWidgets('copies the winners list as text', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpDrawApp(
      tester,
      prefs: {
        DrawStorage.winnersKey: ['5', '17', '250'],
      },
    );

    await tester.tap(find.byTooltip('Copy winners'));
    await tester.pump();

    expect(copied, [
      '${DrawSettings.defaultTitle} – lucky draw winners\n'
          '#1  005\n'
          '#2  017\n'
          '#3  250  (outside the current range)',
    ]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Copied 3 winners to the clipboard.'), findsOneWidget);
  });

  testWidgets('history actions are disabled while the reels spin', (
    tester,
  ) async {
    await pumpDrawApp(
      tester,
      prefs: {
        DrawStorage.winnersKey: ['5'],
      },
    );
    IconButton iconButton(String tooltip) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );

    await tapDraw(tester);

    expect(iconButton('Undo last draw').onPressed, isNull);
    expect(iconButton('Clear all winners').onPressed, isNull);
    expect(iconButton('Remove winner #1').onPressed, isNull);
    expect(iconButton('Draw settings').onPressed, isNull);
    expect(
      iconButton('Copy winners').onPressed,
      isNotNull,
      reason: 'copying changes nothing',
    );

    await pumpThroughSpin(tester);
    expect(iconButton('Undo last draw').onPressed, isNotNull);
    expect(iconButton('Draw settings').onPressed, isNotNull);
  });

  testWidgets('disables Draw once every number has been drawn', (tester) async {
    final controller = await pumpDrawApp(
      tester,
      prefs: {
        DrawStorage.minKey: 1,
        DrawStorage.maxKey: 3,
        DrawStorage.winnersKey: ['1', '2'],
      },
    );
    expect(find.text('1 of 3 numbers left'), findsOneWidget);

    await tapDraw(tester);
    await pumpThroughSpin(tester);

    expect(controller.winners, [1, 2, 3]);
    expect(reelDigits(tester), '3');
    expect(drawButton(tester).onPressed, isNull);
    expect(find.textContaining('That was the last number'), findsOneWidget);

    await tester.tap(resetButtonFinder);
    await tester.pump();
    expect(find.text('Every number has been drawn!'), findsOneWidget);
    expect(drawButton(tester).onPressed, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.phase, DrawPhase.idle);
  });

  testWidgets('restores the previous session on start', (tester) async {
    await pumpDrawApp(
      tester,
      prefs: {
        DrawStorage.titleKey: 'William & Anna',
        DrawStorage.minKey: 1,
        DrawStorage.maxKey: 50,
        DrawStorage.winnersKey: ['7', '12'],
      },
    );

    expect(find.text('William & Anna'), findsOneWidget);
    expect(reelDigits(tester), '??');
    expect(inHistory('07'), findsOneWidget);
    expect(inHistory('12'), findsOneWidget);
    expect(find.text('48 of 50 numbers left'), findsOneWidget);
  });

  testWidgets('settings dialog validates, saves and keeps the winners', (
    tester,
  ) async {
    final controller = await pumpDrawApp(
      tester,
      prefs: {
        DrawStorage.winnersKey: ['150'],
      },
    );

    await tester.tap(find.byTooltip('Draw settings'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The 1 winner drawn so far will be kept'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('titleField')), 'Ada & Grace');
    await tester.enterText(find.byKey(const Key('minField')), '10');
    await tester.enterText(find.byKey(const Key('maxField')), '5');
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('"To" must be at least 10.'), findsOneWidget);
    expect(controller.settings.max, 200, reason: 'nothing saved yet');

    await tester.enterText(find.byKey(const Key('maxField')), '120');
    await tester.pump();
    expect(find.text('111 numbers, shown as 010 to 120.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('allowRepeatsSwitch')));
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.settings.title, 'Ada & Grace');
    expect(controller.settings.min, 10);
    expect(controller.settings.max, 120);
    expect(controller.settings.allowRepeats, isTrue);
    expect(find.text('Ada & Grace'), findsOneWidget);
    expect(controller.winners, [150]);
    expect(find.text('Outside the current range'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(DrawStorage.maxKey), 120);
    expect(prefs.getString(DrawStorage.titleKey), 'Ada & Grace');
  });

  testWidgets('mute toggle is saved and silences the sounds', (tester) async {
    final sounds = RecordingSoundEffects();
    final controller = await pumpDrawApp(tester, sounds: sounds);

    await tester.tap(find.byTooltip('Mute sound'));
    await tester.pump();

    expect(controller.muted, isTrue);
    expect(sounds.muted, isTrue);
    expect(find.byTooltip('Turn sound on'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(DrawStorage.mutedKey), isTrue);
  });

  testWidgets('leaving mid-spin cancels the draw and its timers', (
    tester,
  ) async {
    final sounds = RecordingSoundEffects();
    final controller = await pumpDrawApp(tester, sounds: sounds);
    await tapDraw(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));

    expect(controller.phase, DrawPhase.idle);
    expect(controller.winners, isEmpty);
    expect(sounds.calls, isNot(contains('reveal')));
    expect(sounds.calls.last, 'stop');
  });

  for (final (name, size) in [
    ('portrait phone', const Size(390, 844)),
    ('landscape phone', const Size(844, 390)),
    ('projector', const Size(1920, 1080)),
  ]) {
    testWidgets('lays out on a $name and completes a draw', (tester) async {
      final controller = await pumpDrawApp(tester, size: size);

      expect(find.byType(HistoryPanel), findsOneWidget);
      await tapDraw(tester);
      await pumpThroughSpin(tester);

      expect(controller.winners, [firstWinner]);
      expect(inHistory(firstWinnerLabel), findsOneWidget);
      expect(reelDigits(tester), firstWinnerLabel);
    });
  }
}
