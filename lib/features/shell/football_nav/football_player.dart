import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'football_ball.dart';

enum FootballPlayerPose { idle, kick, receive }

/// Photoreal player with light 3D perspective + pose crossfade.
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
      duration: const Duration(milliseconds: 220),
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
        final yaw = kicking
            ? -0.12
            : receiving
                ? 0.05
                : breath * 0.8;
        final pitch = kicking ? 0.04 : -breath * 0.35;
        final kickMix = kicking ? Curves.easeOut.transform(_kickFlash.value) : 0.0;

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Ground contact shadow (depth cue)
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
                        Colors.black.withValues(alpha: kicking ? 0.45 : 0.32),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Green stadium glow
              Positioned(
                left: w * 0.05,
                right: w * 0.05,
                bottom: 0,
                height: h * 0.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.28),
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
                  ..translateByDouble(0.0, kicking ? -6.0 : breath * -4.0, 0.0, 1.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 1 - kickMix,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x1400FF88),
                          BlendMode.softLight,
                        ),
                        child: Image.asset(
                          'assets/football/player-idle.webp',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/football/player-idle.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: kickMix,
                      child: Image.asset(
                        'assets/football/player-kick.webp',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
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
              if (widget.showBall && !kicking)
                Positioned(
                  left: w * (receiving ? 0.52 : 0.58),
                  bottom: h * 0.03,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX(0.35)
                      ..scaleByDouble(
                        receiving ? 1.05 : 1.0,
                        receiving ? 1.05 : 1.0,
                        receiving ? 1.05 : 1.0,
                        1,
                      ),
                    child: FootballBall(
                      size: widget.compact ? 22 : 30,
                      glow: receiving,
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
