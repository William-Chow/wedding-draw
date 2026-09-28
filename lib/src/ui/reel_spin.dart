import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Timings of the reveal. Reels stop one after another, left to right.
abstract final class SpinTiming {
  /// When the first reel stops.
  static const firstReelStop = Duration(milliseconds: 3000);

  /// When the last reel stops and the winner is revealed.
  static const lastReelStop = Duration(milliseconds: 6000);

  /// How long each reel takes to slow down from full speed to a stop.
  static const brakeDuration = Duration(milliseconds: 1500);

  /// Full speed of a spinning reel, in digits per second.
  static const cruiseSpeed = 24.0;

  /// How long confetti keeps launching after the reveal.
  static const confettiBurst = Duration(seconds: 3);

  /// When reel [index] of [reelCount] stops: the first at [firstReelStop],
  /// the last at [lastReelStop] and any others evenly in between.
  static Duration reelStopTime(int index, int reelCount) {
    if (reelCount <= 1) return lastReelStop;
    final first = firstReelStop.inMicroseconds;
    final last = lastReelStop.inMicroseconds;
    return Duration(
      microseconds: first + (last - first) * index ~/ (reelCount - 1),
    );
  }
}

/// Full speed for most of the time, then a cubic ease-out to rest during the
/// final [brakeFraction]. The speed is continuous at the switch-over point.
class SpinCurve extends Curve {
  const SpinCurve(this.brakeFraction)
    : assert(brakeFraction > 0 && brakeFraction <= 1);

  final double brakeFraction;

  @override
  double transformInternal(double t) {
    final cruise = 1 - brakeFraction;
    // Constant speed that makes the whole curve end exactly at 1.
    final speed = 3 / (1 + 2 * cruise);
    if (t <= cruise) return speed * t;
    final remaining = 1 - (t - cruise) / brakeFraction;
    return speed * cruise +
        speed * brakeFraction / 3 * (1 - remaining * remaining * remaining);
  }
}

/// How one reel moves during a draw.
///
/// Positions count digits scrolled past: position `p` shows digit `p % 10`,
/// and a fractional position sits between two digits.
@immutable
class ReelSpin {
  const ReelSpin({
    required this.from,
    required this.to,
    required this.stopAt,
    required this.curve,
  });

  /// Plans a spin from [fromDigit] that lands on [targetDigit] at [stopTime]
  /// (measured from the start of the draw).
  factory ReelSpin.plan({
    required int targetDigit,
    required Duration stopTime,
    int fromDigit = 0,
  }) {
    assert(targetDigit >= 0 && targetDigit <= 9);
    final seconds = stopTime.inMicroseconds / Duration.microsecondsPerSecond;
    final brake = math.min(
      1.0,
      SpinTiming.brakeDuration.inMicroseconds / stopTime.inMicroseconds,
    );
    // Cruising covers speed × time; braking (a cubic ease-out) covers a
    // third of what cruising would in the same time.
    final idealDistance =
        SpinTiming.cruiseSpeed * seconds * (1 - brake + brake / 3);
    final turns = math.max(1, (idealDistance / 10).round());
    return ReelSpin(
      from: fromDigit,
      to: fromDigit + turns * 10 + (targetDigit - fromDigit) % 10,
      stopAt: stopTime.inMicroseconds / SpinTiming.lastReelStop.inMicroseconds,
      curve: SpinCurve(brake),
    );
  }

  final int from;
  final int to;

  /// The fraction of [SpinTiming.lastReelStop] after which the reel rests.
  final double stopAt;

  final Curve curve;

  int get targetDigit => to % 10;

  /// The reel position at [t], the progress of the whole draw from 0 to 1.
  double positionAt(double t) {
    if (t >= stopAt) return to.toDouble();
    return from + (to - from) * curve.transform(t / stopAt);
  }

  bool isStoppedAt(double t) => t >= stopAt;
}

/// Plans the spin of every reel so that together they show [digits].
///
/// [fromDigits] are the digits currently on show (when drawing again right
/// after a reveal); reels start from zero otherwise.
List<ReelSpin> planReels(String digits, {String? fromDigits}) {
  final start = fromDigits != null && fromDigits.length == digits.length
      ? fromDigits
      : null;
  return [
    for (var i = 0; i < digits.length; i++)
      ReelSpin.plan(
        targetDigit: int.parse(digits[i]),
        stopTime: SpinTiming.reelStopTime(i, digits.length),
        fromDigit: start == null ? 0 : int.parse(start[i]),
      ),
  ];
}
