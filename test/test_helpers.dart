import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wedding_draw/main.dart';
import 'package:wedding_draw/src/audio/sound_effects.dart';
import 'package:wedding_draw/src/draw/draw_controller.dart';
import 'package:wedding_draw/src/settings/draw_storage.dart';
import 'package:wedding_draw/src/ui/number_reels.dart';

/// Records every call so tests can check when sounds play.
class RecordingSoundEffects implements SoundEffects {
  final calls = <String>[];

  @override
  bool muted = false;

  int count(String call) => calls.where((c) => c == call).length;

  @override
  void startSpin() => calls.add('startSpin');

  @override
  void reelStopped() => calls.add('reelStopped');

  @override
  void reveal() => calls.add('reveal');

  @override
  void stop() => calls.add('stop');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

/// Seed used for every widget test, so draws are predictable.
const testSeed = 1;

/// Builds the app on a screen of [size] with [prefs] as the saved data.
Future<DrawController> pumpDrawApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  SoundEffects? sounds,
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final storage = DrawStorage(await SharedPreferences.getInstance());
  final controller = DrawController(storage: storage, random: Random(testSeed));
  await tester.pumpWidget(
    WeddingDrawApp(
      controller: controller,
      sounds: sounds ?? SilentSoundEffects(),
    ),
  );
  await tester.pump();
  return controller;
}

final drawButtonFinder = find.byKey(const Key('drawButton'));
final resetButtonFinder = find.byKey(const Key('resetButton'));

ButtonStyleButton drawButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(drawButtonFinder);

/// The digits currently shown by the reels, e.g. "087" ("?" when idle).
String reelDigits(WidgetTester tester) {
  final reels = find.byType(DigitReel);
  return [
    for (var i = 0; i < reels.evaluate().length; i++)
      tester
          .widgetList<Text>(
            find.descendant(of: reels.at(i), matching: find.byType(Text)),
          )
          .single
          .data,
  ].join();
}
