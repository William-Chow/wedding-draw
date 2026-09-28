import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sound_effects.dart';
import '../draw/draw_controller.dart';
import '../draw/winners_text.dart';
import '../settings/draw_settings.dart';
import 'celebration.dart';
import 'history_panel.dart';
import 'number_reels.dart';
import 'palette.dart';
import 'reel_spin.dart';
import 'settings_dialog.dart';

/// The draw screen: event title, reels, Draw button and the winners list.
class DrawPage extends StatefulWidget {
  const DrawPage({super.key, required this.controller, required this.sounds});

  final DrawController controller;
  final SoundEffects sounds;

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage>
    with SingleTickerProviderStateMixin {
  // Presenter clickers usually send arrow or page keys.
  static final _drawKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.pageDown,
  };
  static final _resetKeys = {
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.pageUp,
  };
  // These also press a focused button, so they only mean "Draw" while no
  // button has keyboard focus.
  static final _buttonKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  late final AnimationController _spin;
  final _confetti = ConfettiController(duration: SpinTiming.confettiBurst);
  final _focusNode = FocusNode(debugLabel: 'Draw page');

  /// How each reel moves in the current draw; null when idle.
  List<ReelSpin>? _spins;
  int _stoppedReels = 0;

  /// Bumped to rebuild the confetti layer, which removes particles that are
  /// still falling (stopping the controller only ends the emission).
  int _confettiRound = 0;

  DrawController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: SpinTiming.lastReelStop)
      ..addListener(_handleSpinTick);
    widget.sounds.muted = _controller.muted;
  }

  @override
  void dispose() {
    _spin.dispose();
    _confetti.dispose();
    _focusNode.dispose();
    widget.sounds.stop();
    // Never leave the controller stuck mid-draw without an animation.
    if (_controller.phase == DrawPhase.spinning) _controller.reset();
    super.dispose();
  }

  void _draw() {
    if (!_controller.canDraw) return;
    // A pending "Undo" must not bring back a number this draw could pick.
    ScaffoldMessenger.of(context).clearSnackBars();
    _confetti.stop();
    final format = _controller.settings.format;
    final previous = _controller.phase == DrawPhase.revealed
        ? _controller.currentNumber
        : null;
    final number = _controller.startDraw();
    setState(() {
      _spins = planReels(
        format(number),
        fromDigits: previous == null ? null : format(previous),
      );
      _stoppedReels = 0;
      _confettiRound++;
    });
    widget.sounds.startSpin();
    _spin.forward(from: 0);
    _focusNode.requestFocus();
  }

  void _handleSpinTick() {
    final spins = _spins;
    if (spins == null || _controller.phase != DrawPhase.spinning) return;
    final stopped = spins.where((spin) => spin.isStoppedAt(_spin.value)).length;
    if (stopped <= _stoppedReels) return;
    _stoppedReels = stopped;
    widget.sounds.reelStopped();
    if (stopped == spins.length) {
      // The last reel has stopped: only now is the winner announced and saved.
      _controller.completeDraw();
      widget.sounds.reveal();
      _confetti.play();
    }
  }

  void _reset() {
    _spin.reset();
    _confetti.stop();
    widget.sounds.stop();
    setState(() {
      _spins = null;
      _stoppedReels = 0;
      _confettiRound++;
    });
    _controller.reset();
    _focusNode.requestFocus();
  }

  void _toggleMuted() {
    final muted = !_controller.muted;
    _controller.setMuted(muted);
    widget.sounds.muted = muted;
    if (!muted && _controller.phase == DrawPhase.spinning) {
      widget.sounds.startSpin();
    }
  }

  Future<void> _openSettings() async {
    if (_controller.phase == DrawPhase.spinning) return;
    final updated = await showDialog<DrawSettings>(
      context: context,
      builder: (context) => SettingsDialog(
        initial: _controller.settings,
        winnerCount: _controller.winners.length,
      ),
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    if (updated == null || _controller.phase == DrawPhase.spinning) return;
    final current = _controller.settings;
    if (updated.min != current.min || updated.max != current.max) {
      _reset(); // The number of reels may change.
    }
    _controller.updateSettings(updated);
  }

  void _removeWinner(int index, {bool undoLast = false}) {
    if (_controller.phase == DrawPhase.spinning) return;
    final winners = _controller.winners;
    if (index < 0 || index >= winners.length) return;
    final number = winners[index];
    // After a reveal, the newest winner is the number on screen.
    if (_controller.phase == DrawPhase.revealed &&
        index == winners.length - 1) {
      _reset();
    }
    _controller.removeWinnerAt(index);
    final label = '#${index + 1} (${_controller.settings.format(number)})';
    _showSnackBar(
      undoLast
          ? 'Took back winner $label. That number can be drawn again.'
          : 'Removed winner $label.',
      onUndo: () => _restoreWinner(index, number),
    );
  }

  void _undoLastWinner() {
    _removeWinner(_controller.winners.length - 1, undoLast: true);
  }

  void _restoreWinner(int index, int number) {
    if (!mounted || _controller.phase == DrawPhase.spinning) return;
    if (!_controller.restoreWinner(index, number)) {
      _showSnackBar(
        '${_controller.settings.format(number)} has been drawn again, '
        'so it was not restored.',
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final count = _controller.winners.length;
    if (count == 0 || _controller.phase == DrawPhase.spinning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ClearAllDialog(count: count),
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    if (confirmed != true || _controller.phase == DrawPhase.spinning) return;
    if (_controller.phase == DrawPhase.revealed) _reset();
    _controller.clearWinners();
    _showSnackBar('All winners cleared. Every number can be drawn again.');
  }

  Future<void> _copyWinners() async {
    final winners = _controller.winners;
    if (winners.isEmpty) return;
    final settings = _controller.settings;
    final count = winners.length;
    final text = winnersAsText(
      title: settings.title,
      winners: winners,
      format: settings.format,
      isInRange: _controller.isInRange,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnackBar(
      count == 1
          ? 'Copied 1 winner to the clipboard.'
          : 'Copied $count winners to the clipboard.',
    );
  }

  void _showSnackBar(String message, {VoidCallback? onUndo}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          width: screenWidth > 640 ? 560 : null,
          persist: false,
          action: onUndo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: onUndo),
        ),
      );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isDrawKey =
        _drawKeys.contains(key) &&
        (node.hasPrimaryFocus || !_buttonKeys.contains(key));
    if (isDrawKey) {
      // Only from idle: a stray clicker press must not skip past a winner.
      if (_controller.phase == DrawPhase.idle) _draw();
      return KeyEventResult.handled;
    }
    if (_resetKeys.contains(key) && _controller.phase == DrawPhase.revealed) {
      _reset();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: WeddingPalette.background),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => LayoutBuilder(builder: _buildLayout),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final history = HistoryPanel(
      winners: _controller.winners,
      format: _controller.settings.format,
      isInRange: _controller.isInRange,
      enabled: _controller.phase != DrawPhase.spinning,
      onRemove: _removeWinner,
      onUndoLast: _undoLastWinner,
      onClearAll: _confirmClearAll,
      onCopy: _copyWinners,
    );
    final landscape =
        constraints.maxWidth >= 600 &&
        constraints.maxWidth > constraints.maxHeight * 1.15;
    final Widget content;
    // The space taken by the history, so the confetti bursts from the stage.
    final EdgeInsets historyInsets;
    if (landscape) {
      final panelWidth = (constraints.maxWidth * 0.28).clamp(260.0, 380.0);
      historyInsets = EdgeInsets.only(right: panelWidth + 16);
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildStage()),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: SizedBox(width: panelWidth, child: history),
          ),
        ],
      );
    } else {
      final panelHeight = (constraints.maxHeight * 0.34).clamp(140.0, 320.0);
      historyInsets = EdgeInsets.only(bottom: panelHeight + 12);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildStage()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(height: panelHeight, child: history),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned(
          left: 0,
          top: 0,
          right: historyInsets.right,
          bottom: historyInsets.bottom,
          child: CelebrationConfetti(
            key: ValueKey(_confettiRound),
            controller: _confetti,
          ),
        ),
      ],
    );
  }

  Widget _buildStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 460;
        final phase = _controller.phase;
        final settings = _controller.settings;
        final toolbar = _StageToolbar(
          muted: _controller.muted,
          settingsEnabled: phase != DrawPhase.spinning,
          onToggleMuted: _toggleMuted,
          onOpenSettings: _openSettings,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? 8 : 16),
          child: Column(
            children: [
              if (compact)
                Row(
                  children: [
                    Expanded(
                      child: _EventHeading(
                        title: settings.title,
                        compact: true,
                      ),
                    ),
                    toolbar,
                  ],
                )
              else ...[
                Align(alignment: Alignment.centerRight, child: toolbar),
                _EventHeading(
                  title: settings.title,
                  compact: false,
                  fontSize: (constraints.maxWidth * 0.045).clamp(28.0, 60.0),
                ),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 24,
                    vertical: compact ? 8 : 20,
                  ),
                  // No Center here: the reels must get the full height so
                  // they can scale up on big screens.
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: _reelsLabel(),
                    child: ExcludeSemantics(
                      child: NumberReels(
                        animation: _spin,
                        digitCount: settings.digitCount,
                        spins: phase == DrawPhase.idle ? null : _spins,
                        revealed: phase == DrawPhase.revealed,
                      ),
                    ),
                  ),
                ),
              ),
              _DrawStatus(controller: _controller, compact: compact),
              SizedBox(height: compact ? 8 : 16),
              _DrawControls(
                phase: phase,
                canDraw: _controller.canDraw,
                compact: compact,
                onDraw: _draw,
                onReset: _reset,
              ),
            ],
          ),
        );
      },
    );
  }

  String _reelsLabel() {
    final number = _controller.currentNumber;
    if (_controller.phase == DrawPhase.revealed && number != null) {
      return 'Winning number ${_controller.settings.format(number)}';
    }
    return _controller.phase == DrawPhase.spinning
        ? 'Drawing a number'
        : 'No number drawn yet';
  }
}

class _StageToolbar extends StatelessWidget {
  const _StageToolbar({
    required this.muted,
    required this.settingsEnabled,
    required this.onToggleMuted,
    required this.onOpenSettings,
  });

  final bool muted;
  final bool settingsEnabled;
  final VoidCallback onToggleMuted;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: muted ? 'Turn sound on' : 'Mute sound',
          icon: Icon(
            muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
          ),
          onPressed: onToggleMuted,
        ),
        IconButton(
          tooltip: 'Draw settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: settingsEnabled ? onOpenSettings : null,
        ),
      ],
    );
  }
}

class _EventHeading extends StatelessWidget {
  const _EventHeading({
    required this.title,
    required this.compact,
    this.fontSize,
  });

  final String title;
  final bool compact;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return Text(
        title.isEmpty ? 'Lucky Draw' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: WeddingPalette.roseDeep,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: fontSize,
              color: WeddingPalette.roseDeep,
              letterSpacing: 0.5,
            ),
          ),
        const SizedBox(height: 6),
        const FittedBox(fit: BoxFit.scaleDown, child: _LuckyDrawOrnament()),
      ],
    );
  }
}

/// "♥ LUCKY DRAW ♥" between two thin gold rules.
class _LuckyDrawOrnament extends StatelessWidget {
  const _LuckyDrawOrnament();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: WeddingPalette.goldText,
      letterSpacing: 4,
    );
    const rule = SizedBox(
      width: 40,
      child: Divider(color: WeddingPalette.gold, thickness: 1),
    );
    const heart = Icon(Icons.favorite, size: 14, color: WeddingPalette.gold);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        rule,
        const SizedBox(width: 8),
        heart,
        const SizedBox(width: 8),
        Text('LUCKY DRAW', style: style),
        const SizedBox(width: 8),
        heart,
        const SizedBox(width: 8),
        rule,
      ],
    );
  }
}

class _DrawStatus extends StatelessWidget {
  const _DrawStatus({required this.controller, required this.compact});

  final DrawController controller;
  final bool compact;

  static const _keepGoing =
      'Clear the winners or widen the range in settings to keep drawing.';

  (String, String?) _message() {
    final settings = controller.settings;
    switch (controller.phase) {
      case DrawPhase.spinning:
        return ('Good luck!', null);
      case DrawPhase.revealed:
        return (
          'Winner #${controller.winners.length}',
          controller.isExhausted
              ? 'Congratulations! That was the last number. $_keepGoing'
              : 'Congratulations!',
        );
      case DrawPhase.idle:
        if (controller.isExhausted) {
          return ('Every number has been drawn!', _keepGoing);
        }
        if (settings.allowRepeats) {
          return (
            'Ready to draw',
            'Numbers ${settings.format(settings.min)} to '
                '${settings.format(settings.max)}, repeats allowed',
          );
        }
        return (
          'Ready to draw',
          '${controller.remainingCount} of ${settings.rangeSize} numbers left',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (headline, detail) = _message();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey('$headline|$detail'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headline,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(color: WeddingPalette.roseDeep),
          ),
          if (detail != null)
            Text(
              detail,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawControls extends StatelessWidget {
  const _DrawControls({
    required this.phase,
    required this.canDraw,
    required this.compact,
    required this.onDraw,
    required this.onReset,
  });

  final DrawPhase phase;
  final bool canDraw;
  final bool compact;
  final VoidCallback onDraw;
  final VoidCallback onReset;

  static bool get _hasKeyboard =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drawButton = FilledButton.icon(
      key: const Key('drawButton'),
      onPressed: canDraw ? onDraw : null,
      icon: Icon(
        phase == DrawPhase.spinning
            ? Icons.hourglass_top
            : Icons.casino_outlined,
      ),
      label: Text(switch (phase) {
        DrawPhase.idle => 'Draw',
        DrawPhase.spinning => 'Drawing…',
        DrawPhase.revealed => 'Draw again',
      }),
      style: FilledButton.styleFrom(
        minimumSize: compact ? const Size(168, 52) : const Size(240, 64),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        textStyle: compact
            ? theme.textTheme.titleMedium
            : theme.textTheme.headlineSmall,
        iconSize: compact ? 22 : 28,
      ),
    );
    final resetButton = TextButton.icon(
      key: const Key('resetButton'),
      onPressed: onReset,
      icon: const Icon(Icons.restart_alt),
      label: const Text('Reset'),
    );
    final revealed = phase == DrawPhase.revealed;
    if (compact) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            drawButton,
            if (revealed) ...[const SizedBox(width: 12), resetButton],
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        drawButton,
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Center(
            child: revealed
                ? resetButton
                : _hasKeyboard
                ? const _KeyboardHint()
                : null,
          ),
        ),
      ],
    );
  }
}

/// "Space or → to draw · Esc or ← to reset", with the arrows as icons (the
/// bundled font has no arrow glyphs).
class _KeyboardHint extends StatelessWidget {
  const _KeyboardHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    WidgetSpan arrow(IconData icon, String label) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(icon, size: 14, color: color, semanticLabel: label),
    );
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Space or '),
          arrow(Icons.arrow_forward, 'right arrow'),
          const TextSpan(text: ' to draw  ·  Esc or '),
          arrow(Icons.arrow_back, 'left arrow'),
          const TextSpan(text: ' to reset'),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(color: color),
    );
  }
}

class _ClearAllDialog extends StatelessWidget {
  const _ClearAllDialog({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.delete_sweep_outlined),
      title: const Text('Clear all winners?'),
      content: Text(
        'This removes ${count == 1 ? 'the only winner' : 'all $count winners'} '
        'from the list, so their numbers can be drawn again. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirmClearAllButton'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clear all'),
        ),
      ],
    );
  }
}
