import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Toza to‘p — navda tekis (3D burilish yo‘q), glow yashil emas.
class FootballBall extends StatelessWidget {
  const FootballBall({
    super.key,
    this.size = 28,
    this.glow = false,
    this.selected = false,
    this.rotation = 0,
    this.trail = false,
    this.flat = false,
  });

  final double size;
  final bool glow;
  final bool selected;
  final double rotation;
  final bool trail;
  /// Nav icon uchun — perspective yo‘q, yumshoq dumaloq mask.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
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
        filterQuality: FilterQuality.high,
      ),
    );

    if (flat) {
      img = ClipOval(
        child: SizedBox(width: size, height: size, child: img),
      );
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected || glow)
              Container(
                width: size * 1.05,
                height: size * 1.05,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            img,
          ],
        ),
      );
    }

    final ball = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateZ(rotation)
        ..rotateX(0.28)
        ..rotateY(-0.12),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: size * 0.55,
                height: size * 0.12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
            ClipOval(child: img),
          ],
        ),
      ),
    );

    if (!trail) return ball;

    return SizedBox(
      width: size * 2.0,
      height: size * 1.3,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          for (var i = 2; i >= 1; i--)
            Positioned(
              right: i * size * 0.22,
              child: Opacity(
                opacity: 0.14 * (3 - i),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 1.0 * i, sigmaY: 0.5),
                  child: Transform.rotate(
                    angle: rotation - i * 0.25,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/football/ball-real.webp',
                        width: size * (1 - i * 0.08),
                        height: size * (1 - i * 0.08),
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/football/ball-real.png',
                          width: size * (1 - i * 0.08),
                          height: size * (1 - i * 0.08),
                        ),
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

class FootballBallPainterIcon extends StatelessWidget {
  const FootballBallPainterIcon({super.key, this.size = 24, this.selected = false});
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FootballBall(size: size, flat: true, selected: selected);
  }
}

double footballSpinForProgress(double t) => t * math.pi * 2.4;
