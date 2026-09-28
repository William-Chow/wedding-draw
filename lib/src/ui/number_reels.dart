import 'package:flutter/material.dart';

import 'palette.dart';
import 'reel_spin.dart';

/// A row of [DigitReel]s that follows [animation] (the draw progress, 0–1)
/// and scales to fill the space it is given.
class NumberReels extends StatelessWidget {
  const NumberReels({
    super.key,
    required this.animation,
    required this.digitCount,
    required this.spins,
    required this.revealed,
  });

  final Animation<double> animation;
  final int digitCount;

  /// One spin per reel, or null to show question marks (nothing drawn).
  final List<ReelSpin>? spins;

  /// Whether the whole number is on show, which makes the reels glow.
  final bool revealed;

  static const _gap = 24.0;

  @override
  Widget build(BuildContext context) {
    final spins = this.spins?.length == digitCount ? this.spins : null;
    return FittedBox(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < digitCount; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                DigitReel(
                  position: spins?[i].positionAt(t),
                  stopped: spins?[i].isStoppedAt(t) ?? false,
                  highlighted: revealed,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One slot-machine reel. It is laid out at a fixed size; [NumberReels]
/// scales it to the screen.
class DigitReel extends StatelessWidget {
  const DigitReel({
    super.key,
    required this.position,
    this.stopped = false,
    this.highlighted = false,
  });

  static const width = 150.0;
  static const height = 200.0;
  static const _radius = 28.0;

  /// Digits scrolled so far (see [ReelSpin]); null shows a question mark.
  final double? position;

  /// Whether the reel has come to rest on its final digit.
  final bool stopped;

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge!.copyWith(
      fontSize: 150,
      height: 1,
      fontWeight: FontWeight.w700,
      color: WeddingPalette.roseDeep,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WeddingPalette.champagne,
            Colors.white,
            WeddingPalette.champagne,
          ],
        ),
        border: Border.all(
          color: WeddingPalette.gold,
          width: highlighted ? 6 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? WeddingPalette.gold.withValues(alpha: 0.6)
                : WeddingPalette.roseDeep.withValues(alpha: 0.12),
            blurRadius: highlighted ? 40 : 18,
            spreadRadius: highlighted ? 4 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius - 3),
        // Fade the digits out towards the top and bottom edges.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, 0.2, 0.8, 1],
          ).createShader(bounds),
          child: _buildFace(style),
        ),
      ),
    );
  }

  Widget _buildFace(TextStyle style) {
    final position = this.position;
    if (position == null) {
      return _Glyph(
        '?',
        style.copyWith(color: WeddingPalette.rose.withValues(alpha: 0.35)),
      );
    }
    final digit = position.floor() % 10;
    if (stopped) {
      // A small "thunk" as the reel lands.
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.25, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: _Glyph('$digit', style),
      );
    }
    // Moving: the current digit slides down as the next one enters from above.
    final offset = position - position.floor();
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(0, offset * height),
          child: _Glyph('$digit', style),
        ),
        Transform.translate(
          offset: Offset(0, (offset - 1) * height),
          child: _Glyph('${(digit + 1) % 10}', style),
        ),
      ],
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: DigitReel.width,
      height: DigitReel.height,
      child: Center(child: Text(text, style: style)),
    );
  }
}
