import 'dart:math';

/// The pure draw logic: which numbers can still be drawn and who has won.
///
/// Winners are kept in draw order. Unless [allowRepeats] is set, every winner
/// inside the current range is excluded from later draws. Winners outside the
/// range (for example after the range was made smaller) stay in the history
/// but no longer affect the pool.
class DrawPool {
  DrawPool({
    required int min,
    required int max,
    bool allowRepeats = false,
    Iterable<int> winners = const [],
    Random? random,
  }) : _random = random ?? Random(),
       _winners = List.of(winners) {
    configure(min: min, max: max, allowRepeats: allowRepeats);
  }

  final Random _random;
  final List<int> _winners;
  late int _min;
  late int _max;
  late bool _allowRepeats;

  int get min => _min;
  int get max => _max;
  bool get allowRepeats => _allowRepeats;

  /// All winners so far, in draw order.
  List<int> get winners => List.unmodifiable(_winners);

  /// How many numbers the range contains.
  int get rangeSize => _max - _min + 1;

  bool isInRange(int number) => number >= _min && number <= _max;

  /// The numbers that can be drawn next, in ascending order.
  List<int> get remaining {
    final taken = _allowRepeats ? const <int>{} : _winners.toSet();
    return [
      for (var n = _min; n <= _max; n++)
        if (!taken.contains(n)) n,
    ];
  }

  int get remainingCount {
    if (_allowRepeats) return rangeSize;
    return rangeSize - _winners.where(isInRange).toSet().length;
  }

  bool get isExhausted => remainingCount == 0;

  /// Changes the range and the repeat rule, keeping all existing winners.
  void configure({
    required int min,
    required int max,
    required bool allowRepeats,
  }) {
    if (min > max) {
      throw ArgumentError('min ($min) must not be greater than max ($max).');
    }
    _min = min;
    _max = max;
    _allowRepeats = allowRepeats;
  }

  /// Picks a number uniformly from [remaining] without recording it.
  ///
  /// Throws a [StateError] when the pool is exhausted.
  int pick() {
    final pool = remaining;
    if (pool.isEmpty) {
      throw StateError('All numbers from $_min to $_max have been drawn.');
    }
    return pool[_random.nextInt(pool.length)];
  }

  /// Records [number] as the next winner.
  void record(int number) {
    if (!isInRange(number)) {
      throw ArgumentError.value(number, 'number', 'is outside $_min–$_max');
    }
    if (!_allowRepeats && _winners.contains(number)) {
      throw StateError('$number has already been drawn.');
    }
    _winners.add(number);
  }

  /// Picks the next winner and records it straight away.
  int draw() {
    final number = pick();
    record(number);
    return number;
  }

  /// Removes and returns the winner at [index] (its number can be drawn again).
  int removeAt(int index) => _winners.removeAt(index);

  /// Removes and returns the most recent winner, or null when there is none.
  int? removeLast() => _winners.isEmpty ? null : _winners.removeLast();

  /// Puts a removed winner back at [index].
  ///
  /// Returns false (and changes nothing) when that would record the same
  /// number twice while repeats are not allowed.
  bool restore(int index, int number) {
    if (!_allowRepeats && _winners.contains(number)) return false;
    _winners.insert(index.clamp(0, _winners.length), number);
    return true;
  }

  /// Removes every winner, so all numbers can be drawn again.
  void clear() => _winners.clear();
}
