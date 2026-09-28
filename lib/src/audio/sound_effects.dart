import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The sounds played by the draw screen.
///
/// Implementations must never throw: a missing speaker or a failing audio
/// plugin must not break the draw.
abstract interface class SoundEffects {
  bool get muted;
  set muted(bool value);

  /// Starts the drum roll that loops while the reels spin.
  void startSpin();

  /// Called each time a reel comes to rest.
  void reelStopped();

  /// Stops the drum roll and plays the winning chime.
  void reveal();

  /// Silences everything that is playing.
  void stop();

  Future<void> dispose();
}

/// Plays nothing. Used in tests.
class SilentSoundEffects implements SoundEffects {
  @override
  bool muted = false;

  @override
  void startSpin() {}

  @override
  void reelStopped() {}

  @override
  void reveal() {}

  @override
  void stop() {}

  @override
  Future<void> dispose() async {}
}

/// [SoundEffects] backed by the audioplayers plugin and the synthesized
/// clips in `assets/sounds/`.
class AudioPlayersSoundEffects implements SoundEffects {
  final _drumRoll = _Clip('sounds/drum_roll.wav', loop: true, volume: 0.8);
  final _reelStop = _Clip('sounds/reel_stop.wav');
  final _chime = _Clip('sounds/chime.wav');

  bool _muted = false;

  List<_Clip> get _clips => [_drumRoll, _reelStop, _chime];

  /// Loads the clips ahead of time so the first draw plays without delay.
  void preload() {
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile && !kIsWeb) {
      // Mix with other audio (e.g. background music) instead of pausing it.
      _guard(
        'configure audio',
        () => AudioPlayer.global.setAudioContext(
          AudioContextConfig(
            focus: AudioContextConfigFocus.mixWithOthers,
          ).build(),
        ),
      );
    }
    for (final clip in _clips) {
      _guard('load ${clip.asset}', clip.load);
    }
  }

  @override
  bool get muted => _muted;

  @override
  set muted(bool value) {
    _muted = value;
    if (value) stop();
  }

  @override
  void startSpin() {
    if (!_muted) _guard('play drum roll', _drumRoll.play);
  }

  @override
  void reelStopped() {
    if (!_muted) _guard('play reel stop', _reelStop.play);
  }

  @override
  void reveal() {
    _guard('stop drum roll', _drumRoll.stop);
    if (!_muted) _guard('play chime', _chime.play);
  }

  @override
  void stop() {
    for (final clip in _clips) {
      _guard('stop ${clip.asset}', clip.stop);
    }
  }

  @override
  Future<void> dispose() async {
    for (final clip in _clips) {
      await _guarded('dispose ${clip.asset}', clip.dispose);
    }
  }

  static void _guard(String action, Future<void> Function() task) {
    unawaited(_guarded(action, task));
  }

  static Future<void> _guarded(
    String action,
    Future<void> Function() task,
  ) async {
    try {
      await task();
    } catch (error) {
      debugPrint('Sound effect failed ($action): $error');
    }
  }
}

/// One audio clip with its own player, created on first use.
class _Clip {
  _Clip(this.asset, {this.loop = false, this.volume = 1.0});

  final String asset;
  final bool loop;
  final double volume;

  AudioPlayer? _player;
  Future<AudioPlayer>? _loading;

  // Tracks the latest request, so a stop() that arrives while the clip is
  // still loading wins over the play() before it.
  bool _wantsToPlay = false;

  Future<AudioPlayer> _ensureLoaded() {
    return _loading ??= () async {
      final player = _player = AudioPlayer();
      await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await player.setVolume(volume);
      await player.setSource(AssetSource(asset));
      return player;
    }();
  }

  Future<void> load() => _ensureLoaded();

  Future<void> play() async {
    _wantsToPlay = true;
    final player = await _ensureLoaded();
    if (!_wantsToPlay) return;
    await player.stop(); // Rewind, so a replay starts from the beginning.
    if (_wantsToPlay) await player.resume();
  }

  Future<void> stop() async {
    _wantsToPlay = false;
    await _player?.stop();
  }

  Future<void> dispose() async {
    _wantsToPlay = false;
    await _player?.dispose();
    _player = null;
    _loading = null;
  }
}
