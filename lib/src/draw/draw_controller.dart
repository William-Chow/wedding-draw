import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../settings/draw_settings.dart';
import '../settings/draw_storage.dart';
import 'draw_pool.dart';

enum DrawPhase {
  /// Waiting for the next draw.
  idle,

  /// The reels are spinning towards a number that is not announced yet.
  spinning,

  /// The winning number is on screen and recorded in the history.
  revealed,
}

/// App state: the settings, the winners and where the current draw is.
///
/// Every change is saved through [DrawStorage] right away, so restarting the
/// app in the middle of an event keeps the winners and avoids repeats.
class DrawController extends ChangeNotifier {
  DrawController({required DrawStorage storage, Random? random})
    : _storage = storage,
      _settings = storage.loadSettings(),
      _muted = storage.loadMuted() {
    _pool = DrawPool(
      min: _settings.min,
      max: _settings.max,
      allowRepeats: _settings.allowRepeats,
      winners: storage.loadWinners(),
      random: random,
    );
  }

  final DrawStorage _storage;
  late final DrawPool _pool;
  DrawSettings _settings;
  bool _muted;
  DrawPhase _phase = DrawPhase.idle;
  int? _currentNumber;

  DrawSettings get settings => _settings;
  DrawPhase get phase => _phase;
  bool get muted => _muted;

  /// The number being drawn (while spinning) or just drawn (once revealed).
  int? get currentNumber => _currentNumber;

  /// All winners so far, in draw order.
  List<int> get winners => _pool.winners;

  int get remainingCount => _pool.remainingCount;
  bool get isExhausted => _pool.isExhausted;
  bool get canDraw => _phase != DrawPhase.spinning && !_pool.isExhausted;

  bool isInRange(int number) => _pool.isInRange(number);

  /// Picks the next winner and starts spinning.
  ///
  /// The number is only added to [winners] by [completeDraw], once the reveal
  /// has finished.
  int startDraw() {
    if (!canDraw) throw StateError('A draw cannot be started right now.');
    final number = _pool.pick();
    _currentNumber = number;
    _phase = DrawPhase.spinning;
    notifyListeners();
    return number;
  }

  /// Records the number chosen by [startDraw] and shows it as the winner.
  void completeDraw() {
    final number = _currentNumber;
    if (_phase != DrawPhase.spinning || number == null) return;
    _pool.record(number);
    _phase = DrawPhase.revealed;
    _saveWinners();
    notifyListeners();
  }

  /// Returns to idle. A number that was still spinning is discarded.
  void reset() {
    if (_phase == DrawPhase.idle) return;
    _phase = DrawPhase.idle;
    _currentNumber = null;
    notifyListeners();
  }

  /// Applies new settings. Winners are kept; only those inside the new range
  /// are excluded from future draws.
  void updateSettings(DrawSettings settings) {
    final problem = DrawSettings.validateRange(settings.min, settings.max);
    if (problem != null) throw ArgumentError(problem);
    if (_phase == DrawPhase.spinning) {
      throw StateError('Settings cannot change while the reels are spinning.');
    }
    if (settings == _settings) return;
    if (settings.min != _settings.min || settings.max != _settings.max) {
      // The reels are about to change size, so drop the number on show.
      _phase = DrawPhase.idle;
      _currentNumber = null;
    }
    _settings = settings;
    _pool.configure(
      min: settings.min,
      max: settings.max,
      allowRepeats: settings.allowRepeats,
    );
    unawaited(_storage.saveSettings(settings));
    notifyListeners();
  }

  /// Removes the winner at [index]; its number can be drawn again.
  int removeWinnerAt(int index) {
    _ensureNotSpinning();
    final number = _pool.removeAt(index);
    _saveWinners();
    notifyListeners();
    return number;
  }

  /// Removes the most recent winner, returning it (or null if there is none).
  int? undoLastWinner() {
    _ensureNotSpinning();
    final number = _pool.removeLast();
    if (number == null) return null;
    _saveWinners();
    notifyListeners();
    return number;
  }

  /// Puts a removed winner back at [index]. Returns false when the number
  /// has been drawn again in the meantime and repeats are not allowed.
  bool restoreWinner(int index, int number) {
    _ensureNotSpinning();
    if (!_pool.restore(index, number)) return false;
    _saveWinners();
    notifyListeners();
    return true;
  }

  void clearWinners() {
    _ensureNotSpinning();
    if (_pool.winners.isEmpty) return;
    _pool.clear();
    _saveWinners();
    notifyListeners();
  }

  void setMuted(bool muted) {
    if (muted == _muted) return;
    _muted = muted;
    unawaited(_storage.saveMuted(muted));
    notifyListeners();
  }

  void _ensureNotSpinning() {
    if (_phase == DrawPhase.spinning) {
      throw StateError('Winners cannot change while the reels are spinning.');
    }
  }

  void _saveWinners() => unawaited(_storage.saveWinners(_pool.winners));
}
