import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'draw_settings.dart';

/// Saves the settings, the winners list and the mute flag on the device.
///
/// Reads fall back to defaults when a value is missing or malformed, and
/// failed writes are only logged, so storage problems never interrupt a draw.
class DrawStorage {
  DrawStorage(SharedPreferences prefs) : _prefs = prefs;

  /// Storage that keeps nothing between launches.
  DrawStorage.inMemory() : _prefs = null;

  /// Opens the device storage, or falls back to [DrawStorage.inMemory] when
  /// it is unavailable.
  static Future<DrawStorage> open() async {
    try {
      return DrawStorage(await SharedPreferences.getInstance());
    } catch (error) {
      debugPrint('Saving is unavailable, continuing without it: $error');
      return DrawStorage.inMemory();
    }
  }

  static const titleKey = 'settings.title';
  static const minKey = 'settings.min';
  static const maxKey = 'settings.max';
  static const allowRepeatsKey = 'settings.allowRepeats';
  static const winnersKey = 'draw.winners';
  static const mutedKey = 'sound.muted';

  final SharedPreferences? _prefs;

  DrawSettings loadSettings() {
    const defaults = DrawSettings();
    final title = _read<String>(titleKey) ?? defaults.title;
    final min = _read<int>(minKey) ?? defaults.min;
    final max = _read<int>(maxKey) ?? defaults.max;
    final allowRepeats = _read<bool>(allowRepeatsKey) ?? defaults.allowRepeats;
    if (DrawSettings.validateRange(min, max) != null) {
      return defaults.copyWith(title: title, allowRepeats: allowRepeats);
    }
    return DrawSettings(
      title: title,
      min: min,
      max: max,
      allowRepeats: allowRepeats,
    );
  }

  Future<void> saveSettings(DrawSettings settings) {
    return _write(
      (prefs) => Future.wait([
        prefs.setString(titleKey, settings.title),
        prefs.setInt(minKey, settings.min),
        prefs.setInt(maxKey, settings.max),
        prefs.setBool(allowRepeatsKey, settings.allowRepeats),
      ]),
    );
  }

  /// The saved winners in draw order; unreadable entries are skipped.
  List<int> loadWinners() {
    final stored = _read<List<Object?>>(winnersKey) ?? const [];
    return [
      for (final entry in stored)
        if (int.tryParse('$entry') case final number?)
          if (number >= 0 && number <= DrawSettings.maxSupportedNumber) number,
    ];
  }

  Future<void> saveWinners(List<int> winners) {
    return _write(
      (prefs) => prefs.setStringList(winnersKey, [
        for (final number in winners) '$number',
      ]),
    );
  }

  bool loadMuted() => _read<bool>(mutedKey) ?? false;

  Future<void> saveMuted(bool muted) {
    return _write((prefs) => prefs.setBool(mutedKey, muted));
  }

  T? _read<T>(String key) {
    final value = _prefs?.get(key);
    return value is T ? value : null;
  }

  Future<void> _write(
    Future<void> Function(SharedPreferences prefs) write,
  ) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await write(prefs);
    } catch (error) {
      debugPrint('Could not save the draw: $error');
    }
  }
}
