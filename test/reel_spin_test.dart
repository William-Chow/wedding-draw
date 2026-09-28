import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_draw/src/ui/reel_spin.dart';

void main() {
  group('SpinTiming', () {
    test('staggers the reels between the first and last stop', () {
      List<int> stops(int reels) => [
        for (var i = 0; i < reels; i++)
          SpinTiming.reelStopTime(i, reels).inMilliseconds,
      ];

      expect(stops(3), [3000, 4500, 6000]);
      expect(stops(1), [6000]);
      expect(stops(2), [3000, 6000]);
      expect(stops(5), [3000, 3750, 4500, 5250, 6000]);
    });
  });

  group('SpinCurve', () {
    for (final brake in [0.25, 0.5, 1.0]) {
      test('runs from 0 to 1 without reversing (brake $brake)', () {
        final curve = SpinCurve(brake);
        expect(curve.transform(0), 0);
        expect(curve.transform(1), 1);
        var previous = 0.0;
        for (var i = 1; i <= 1000; i++) {
          final value = curve.transform(i / 1000);
          expect(value, greaterThanOrEqualTo(previous));
          previous = value;
        }
      });
    }

    test('keeps a constant speed, then slows down smoothly to a stop', () {
      const curve = SpinCurve(0.4);
      double speedAt(double t) =>
          (curve.transform(t + 1e-4) - curve.transform(t - 1e-4)) / 2e-4;

      expect(speedAt(0.1), closeTo(speedAt(0.5), 1e-6));
      expect(speedAt(0.6 + 1e-3), closeTo(speedAt(0.6 - 1e-3), 1e-2));
      expect(speedAt(0.9), lessThan(speedAt(0.7)));
      expect(speedAt(1 - 1e-3), closeTo(0, 1e-2));
    });
  });

  group('ReelSpin', () {
    test('lands on the target digit when it stops', () {
      for (var digit = 0; digit <= 9; digit++) {
        final spin = ReelSpin.plan(
          targetDigit: digit,
          stopTime: SpinTiming.firstReelStop,
          fromDigit: 7,
        );

        expect(spin.positionAt(0), 7);
        expect(spin.targetDigit, digit);
        expect(spin.positionAt(spin.stopAt), spin.to);
        expect(spin.positionAt(1), spin.to);
        expect(spin.to - spin.from, greaterThanOrEqualTo(20));
      }
    });

    test('keeps moving until its stop time', () {
      final spin = ReelSpin.plan(
        targetDigit: 4,
        stopTime: SpinTiming.firstReelStop,
      );

      expect(spin.stopAt, 0.5);
      expect(spin.isStoppedAt(0.49), isFalse);
      expect(spin.isStoppedAt(0.5), isTrue);
      expect(spin.positionAt(0.25), greaterThan(0));
      expect(spin.positionAt(0.49), lessThan(spin.to));
    });
  });

  test('planReels spins one reel per digit, stopping left to right', () {
    final spins = planReels('087');

    expect(spins.map((s) => s.targetDigit), [0, 8, 7]);
    expect(spins.map((s) => s.stopAt), [0.5, 0.75, 1.0]);
    expect(spins.map((s) => s.from), [0, 0, 0]);
  });

  test('planReels continues from the digits on show', () {
    final spins = planReels('087', fromDigits: '153');

    expect(spins.map((s) => s.from), [1, 5, 3]);
    expect(spins.map((s) => s.targetDigit), [0, 8, 7]);
    expect(planReels('42', fromDigits: '153').map((s) => s.from), [0, 0]);
  });
}
