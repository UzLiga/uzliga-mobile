import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Photoreal ball — transparent cutout, no green tint.
class FootballBall extends StatelessWidget {
  const FootballBall({
    super.key,
    this.size = 28,
    this.glow = false,
    this.selected = false,
    this.rotation = 0,
    this.trail = false,
  });

  final double size;
  final bool glow;
  final bool selected;
  final double rotation;
  final bool trail;

  @override
  Widget build(BuildContext context) {
    final ball = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateZ(rotation)
        ..rotateX(0.55)
        ..rotateY(-0.25),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Neutral depth shadow only (no mint/green)
            if (glow || selected)
              Container(
                width: size * 1.15,
                height: size * 1.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            Positioned(
              bottom: 1,
              child: Container(
                width: size * 0.65,
                height: size * 0.16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ),
            Image.asset(
              'assets/football/ball-real.webp',
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/football/ball-real.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );

    if (!trail) return ball;

    return SizedBox(
      width: size * 2.2,
      height: size * 1.4,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          for (var i = 3; i >= 1; i--)
            Positioned(
              right: i * size * 0.28,
              child: Opacity(
                opacity: 0.12 * (4 - i),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 1.2 * i, sigmaY: 0.6),
                  child: Transform.rotate(
                    angle: rotation - i * 0.35,
                    child: Image.asset(
                      'assets/football/ball-real.webp',
                      width: size * (1 - i * 0.06),
                      height: size * (1 - i * 0.06),
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/football/ball-real.png',
                        width: size * (1 - i * 0.06),
                        height: size * (1 - i * 0.06),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ball,
        ],
      ),
    );
  }
}

/// Fallback painter if assets fail — kept for nav-bar tiny icons optional.
class FootballBallPainterIcon extends StatelessWidget {
  const FootballBallPainterIcon({super.key, this.size = 24, this.selected = false});
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FootballBall(size: size, selected: selected, glow: selected);
  }
}

double footballSpinForProgress(double t) => t * math.pi * 3.2;
