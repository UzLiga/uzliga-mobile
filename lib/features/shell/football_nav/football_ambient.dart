import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'football_nav_controller.dart';
import 'football_player.dart';

/// Full-bleed Cyber Mint stage — player lives in the page atmosphere.
/// Shown on Asosiy / O‘yinlar / Profil; hidden on Lavhalar (video).
class FootballAmbientBackdrop extends ConsumerWidget {
  const FootballAmbientBackdrop({
    super.key,
    required this.tabIndex,
  });

  final int tabIndex;

  bool get _visible => tabIndex != 2; // reels stays cinematic black

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_visible) return const SizedBox.shrink();

    final phase = ref.watch(
      footballNavProvider.select((t) => t?.phase),
    );
    final pose = ref.watch(
      footballNavProvider.select((t) {
        if (t == null) return FootballPlayerPose.idle;
        if (t.reverse && t.phase == FootballNavPhase.receive) {
          return FootballPlayerPose.receive;
        }
        if (t.phase == FootballNavPhase.kick || t.phase == FootballNavPhase.fly) {
          return FootballPlayerPose.kick;
        }
        return FootballPlayerPose.idle;
      }),
    );

    final size = MediaQuery.sizeOf(context);
    final playerH = (size.height * 0.72).clamp(320.0, 560.0);

    // Per-tab framing so it feels designed, not copy-paste
    final align = switch (tabIndex) {
      1 => Alignment.centerRight, // games
      3 => Alignment.bottomRight, // profile
      _ => Alignment.centerRight, // home
    };
    final opacity = switch (tabIndex) {
      1 => 0.78,
      3 => 0.72,
      _ => 0.92,
    };
    final scale = switch (tabIndex) {
      1 => 1.2,
      3 => 1.1,
      _ => 1.28,
    };

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF041510),
                  Color(0xFF06281C),
                  Color(0xFF03140F),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.75, -0.1),
                radius: 1.15,
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
                  AppColors.primary.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0, 0.35, 1],
              ),
            ),
          ),
          CustomPaint(painter: _MintGridPainter()),
          // Player — oq fon yo‘q, toza cutout
          Align(
            alignment: align,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(size.width * 0.06, tabIndex == 3 ? 24 : 8),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: FootballPlayer(
                    height: playerH,
                    pose: pose,
                    showBall: phase == FootballNavPhase.kick ||
                        phase == FootballNavPhase.receive,
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.bg.withValues(alpha: 0.82),
                  AppColors.bg.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                stops: const [0, 0.42, 0.78],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.bg.withValues(alpha: 0.55),
                ],
                stops: const [0.72, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00CC7A).withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const step = 42.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
