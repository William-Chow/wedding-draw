import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'palette.dart';

/// A burst of hearts and paper confetti, fired by [controller].
class CelebrationConfetti extends StatelessWidget {
  const CelebrationConfetti({super.key, required this.controller});

  final ConfettiController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 16,
          minBlastForce: 10,
          maxBlastForce: 40,
          gravity: 0.15,
          minimumSize: const Size(12, 10),
          maximumSize: const Size(26, 18),
          colors: WeddingPalette.confetti,
          createParticlePath: _particleShape,
          // Keep celebrating on slower machines (e.g. a laptop driving a
          // projector); by default emission pauses below 60 fps.
          pauseEmissionOnLowFrameRate: false,
        ),
      ),
    );
  }
}

final _shapeRandom = Random();

Path _particleShape(Size size) {
  if (_shapeRandom.nextInt(3) == 0) {
    return Path()..addRect(Offset.zero & Size(size.width, size.height / 2));
  }
  return _heartPath(size.width);
}

/// A heart that fits in a square of the given [size].
Path _heartPath(double size) {
  final s = size;
  return Path()
    ..moveTo(s * 0.5, s * 0.95)
    ..cubicTo(s * 0.1, s * 0.7, -s * 0.05, s * 0.35, s * 0.2, s * 0.15)
    ..cubicTo(s * 0.35, 0, s * 0.5, s * 0.1, s * 0.5, s * 0.3)
    ..cubicTo(s * 0.5, s * 0.1, s * 0.65, 0, s * 0.8, s * 0.15)
    ..cubicTo(s * 1.05, s * 0.35, s * 0.9, s * 0.7, s * 0.5, s * 0.95)
    ..close();
}
