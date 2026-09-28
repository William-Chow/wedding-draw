import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_draw/src/draw/draw_pool.dart';

void main() {
  group('DrawPool', () {
    test('draws every number in the range exactly once', () {
      final pool = DrawPool(min: 1, max: 50, random: Random(3));

      final drawn = [for (var i = 0; i < 50; i++) pool.draw()];

      expect(drawn.toSet(), hasLength(50), reason: 'no duplicates');
      expect(drawn.toSet(), {for (var n = 1; n <= 50; n++) n});
      expect(pool.winners, drawn);
    });

    test('is exhausted once every number has been drawn', () {
      final pool = DrawPool(min: 7, max: 9, random: Random(1));
      expect(pool.remainingCount, 3);

      pool
        ..draw()
        ..draw();
      expect(pool.isExhausted, isFalse);
      expect(pool.remainingCount, 1);

      pool.draw();
      expect(pool.isExhausted, isTrue);
      expect(pool.remainingCount, 0);
      expect(pool.remaining, isEmpty);
      expect(pool.pick, throwsStateError);
      expect(pool.draw, throwsStateError);
    });

    test('pick does not record the number', () {
      final pool = DrawPool(min: 1, max: 10, random: Random(1));

      final number = pool.pick();

      expect(number, inInclusiveRange(1, 10));
      expect(pool.winners, isEmpty);
      expect(pool.remainingCount, 10);
    });

    test('picks uniformly from the numbers that are left', () {
      final pool = DrawPool(min: 1, max: 4, winners: [1, 2], random: Random(5));
      final counts = <int, int>{};

      for (var i = 0; i < 4000; i++) {
        counts.update(pool.pick(), (c) => c + 1, ifAbsent: () => 1);
      }

      expect(counts.keys.toSet(), {3, 4});
      expect(counts[3], inInclusiveRange(1800, 2200));
      expect(counts[4], inInclusiveRange(1800, 2200));
    });

    test('is deterministic for a seeded Random', () {
      List<int> sequence(int seed) {
        final pool = DrawPool(min: 1, max: 200, random: Random(seed));
        return [for (var i = 0; i < 20; i++) pool.draw()];
      }

      expect(sequence(42), sequence(42));
      expect(sequence(42), isNot(sequence(43)));
    });

    test('record rejects duplicates and numbers outside the range', () {
      final pool = DrawPool(min: 1, max: 10, winners: [4]);

      expect(() => pool.record(4), throwsStateError);
      expect(() => pool.record(0), throwsArgumentError);
      expect(() => pool.record(11), throwsArgumentError);
      expect(pool.winners, [4]);
    });

    test('allows repeats when configured', () {
      final pool = DrawPool(
        min: 1,
        max: 3,
        allowRepeats: true,
        random: Random(2),
      );

      final drawn = [for (var i = 0; i < 30; i++) pool.draw()];

      expect(drawn, hasLength(30));
      expect(drawn.toSet().length, lessThan(30));
      expect(drawn.every((n) => n >= 1 && n <= 3), isTrue);
      expect(pool.remainingCount, 3);
      expect(pool.isExhausted, isFalse);
    });

    test('turning repeats off excludes every earlier winner once', () {
      final pool = DrawPool(
        min: 1,
        max: 5,
        allowRepeats: true,
        winners: [2, 2, 4],
      );

      pool.configure(min: 1, max: 5, allowRepeats: false);

      expect(pool.remaining, [1, 3, 5]);
      expect(pool.remainingCount, 3);
    });

    test(
      'changing the range keeps winners but only excludes those in range',
      () {
        final pool = DrawPool(
          min: 1,
          max: 200,
          winners: [5, 150],
          random: Random(1),
        );

        pool.configure(min: 1, max: 100, allowRepeats: false);

        expect(pool.winners, [5, 150]);
        expect(pool.isInRange(150), isFalse);
        expect(pool.remainingCount, 99);
        expect(pool.remaining, isNot(contains(5)));
        expect(pool.remaining.last, 100);

        pool.configure(min: 1, max: 200, allowRepeats: false);
        expect(pool.remainingCount, 198);
        expect(pool.remaining, isNot(contains(150)));
      },
    );

    test('rejects a range whose minimum is above its maximum', () {
      expect(() => DrawPool(min: 10, max: 9), throwsArgumentError);
      final pool = DrawPool(min: 1, max: 9);
      expect(
        () => pool.configure(min: 5, max: 4, allowRepeats: false),
        throwsArgumentError,
      );
      expect(pool.max, 9);
    });

    test('removing and restoring winners', () {
      final pool = DrawPool(min: 1, max: 10, winners: [3, 6, 9]);

      expect(pool.removeAt(1), 6);
      expect(pool.winners, [3, 9]);
      expect(pool.remaining, contains(6));

      expect(pool.restore(1, 6), isTrue);
      expect(pool.winners, [3, 6, 9]);
      expect(pool.restore(0, 6), isFalse, reason: 'already a winner');

      expect(pool.removeLast(), 9);
      expect(pool.winners, [3, 6]);

      pool.clear();
      expect(pool.winners, isEmpty);
      expect(pool.removeLast(), isNull);
      expect(pool.remainingCount, 10);
    });

    test('winners cannot be modified from outside', () {
      final pool = DrawPool(min: 1, max: 10, winners: [1]);
      expect(() => pool.winners.add(2), throwsUnsupportedError);
    });
  });
}
