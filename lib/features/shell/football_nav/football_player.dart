import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'football_ball.dart';

enum FootballPlayerPose { idle, kick, receive }

/// Photoreal player — kickda oyog‘i oldinga, to‘p oyog‘iga tegib ko‘rinadi.
class FootballPlayer extends StatefulWidget {
  const FootballPlayer({
    super.key,
    this.height = 168,
    this.pose = FootballPlayerPose.idle,
    this.showBall = true,
    this.compact = false,
  });

  final double height;
  final FootballPlayerPose pose;
  final bool showBall;
  final bool compact;

  @override
  State<FootballPlayer> createState() => _FootballPlayerState();
}

class _FootballPlayerState extends State<FootballPlayer>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _kickFlash;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _kickFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    if (widget.pose == FootballPlayerPose.idle) {
      _idle.repeat(reverse: true);
    } else if (widget.pose == FootballPlayerPose.kick) {
      _kickFlash.forward();
    }
  }

  @override
  void didUpdateWidget(covariant FootballPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pose == FootballPlayerPose.idle) {
      if (!_idle.isAnimating) _idle.repeat(reverse: true);
      _kickFlash.value = 0;
    } else {
      _idle.stop();
      if (widget.pose == FootballPlayerPose.kick &&
          oldWidget.pose != FootballPlayerPose.kick) {
        _kickFlash.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _kickFlash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final h = widget.height;
    final w = h * 0.72;
    final kicking = widget.pose == FootballPlayerPose.kick;
    final receiving = widget.pose == FootballPlayerPose.receive;

    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _kickFlash]),
      builder: (context, _) {
        final breath = reduce ? 0.0 : math.sin(_idle.value * math.pi) * 0.018;
        final kickMix =
            kicking ? Curves.easeOutCubic.transform(_kickFlash.value) : 0.0;
        // Oyoq oldinga — engil, haddan tashqari 3D yo‘q
        final yaw = kicking
            ? -0.04 - kickMix * 0.05
            : receiving
                ? 0.03
                : breath * 0.35;
        final pitch = kicking ? 0.01 : -breath * 0.15;
        final leanX = kicking ? -6.0 - kickMix * 8.0 : breath * -1.5;

        // To‘p oyog‘i oldida — kickda biroz oldinga “tegish”
        final ballLeft = w * (receiving
            ? 0.50
            : kicking
                ? (0.42 - kickMix * 0.06)
                : 0.48);
        final ballBottom = h * (kicking ? (0.045 + kickMix * 0.01) : 0.035);

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: w * 0.18,
                right: w * 0.12,
                bottom: 2,
                height: h * 0.08,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: kicking ? 0.4 : 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateY(yaw)
                  ..rotateX(pitch)
                  ..translateByDouble(leanX, kicking ? -2.0 : breath * -4.0, 0.0, 1.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 1 - kickMix,
                      child: Image.asset(
                        'assets/football/player-idle.webp',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/football/player-idle.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: kickMix,
                      child: Image.asset(
                        'assets/football/player-kick.webp',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/football/player-kick.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Kickda ham to‘p oyog‘ida — uchib ketgunga qadar “tegish”
              if (widget.showBall)
                Positioned(
                  left: ballLeft,
                  bottom: ballBottom,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX(0.35)
                      ..rotateZ(kicking ? -kickMix * 0.4 : 0)
                      ..scaleByDouble(
                        kicking ? 1.0 - kickMix * 0.05 : receiving ? 1.05 : 1.0,
                        kicking ? 1.0 - kickMix * 0.05 : receiving ? 1.05 : 1.0,
                        1,
                        1,
                      ),
                    child: FootballBall(
                      size: widget.compact ? 22 : (kicking ? 28 : 30),
                      glow: receiving || kicking,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
