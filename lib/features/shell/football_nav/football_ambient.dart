import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'football_nav_controller.dart';
import 'football_player.dart';

/// Ambient o‘yinchi — yumshoq fade, “stiker” emas.
class FootballAmbientBackdrop extends ConsumerWidget {
  const FootballAmbientBackdrop({
    super.key,
    required this.tabIndex,
  });

  final int tabIndex;

  bool get _visible => tabIndex != 2;

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
    final playerH = (size.height * 0.58).clamp(280.0, 460.0);

    final align = switch (tabIndex) {
      1 => Alignment.centerRight,
      3 => Alignment.bottomRight,
      _ => Alignment.centerRight,
    };
    final opacity = switch (tabIndex) {
      1 => 0.48,
      3 => 0.42,
      _ => 0.55,
    };
    final scale = switch (tabIndex) {
      1 => 1.05,
      3 => 1.0,
      _ => 1.08,
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
                  Color(0xFF06140F),
                  Color(0xFF0A1C14),
                  Color(0xFF050E0A),
                ],
              ),
            ),
          ),
          // Yumshoq chuqurlik — yashil “plash” emas
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, 0.1),
                radius: 0.95,
                colors: [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Align(
            alignment: align,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(size.width * 0.08, tabIndex == 3 ? 36 : 16),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.9),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.18, 0.45, 1.0],
                      ).createShader(bounds);
                    },
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0xCCFFFFFF),
                            Color(0xFFFFFFFF),
                            Color(0xE6FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                          stops: [0.0, 0.12, 0.35, 0.78, 1.0],
                        ).createShader(bounds);
                      },
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
            ),
          ),
          // Chap kontent o‘qilishi
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.bg.withValues(alpha: 0.92),
                  AppColors.bg.withValues(alpha: 0.55),
                  AppColors.bg.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0, 0.38, 0.62, 0.88],
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
                  AppColors.bg.withValues(alpha: 0.65),
                ],
                stops: const [0.68, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
