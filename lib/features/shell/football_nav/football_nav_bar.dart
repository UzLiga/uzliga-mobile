import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'football_ball.dart';
import 'football_nav_controller.dart';
import 'football_player.dart';

class FootballNavBar extends ConsumerWidget {
  const FootballNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (0, 'Asosiy', Icons.home_rounded),
    (1, 'O‘yinlar', Icons.sports_soccer_rounded),
    (2, 'Lavhalar', Icons.movie_filter_rounded),
    (3, 'Profil', Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final transition = ref.watch(footballNavProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xCC0B221A),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  for (final item in _items)
                    Expanded(
                      child: _TabHit(
                        label: item.$2,
                        icon: item.$3,
                        selected: selectedIndex == item.$1,
                        pulsing: transition?.to == item.$1 &&
                            (transition?.phase == FootballNavPhase.fly ||
                                transition?.phase ==
                                    FootballNavPhase.receive),
                        onTap: () => onSelect(item.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabHit extends StatefulWidget {
  const _TabHit({
    required this.label,
    required this.icon,
    required this.selected,
    required this.pulsing,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool pulsing;
  final VoidCallback onTap;

  @override
  State<_TabHit> createState() => _TabHitState();
}

class _TabHitState extends State<_TabHit> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected || widget.pulsing;
    final scale = _pressed ? 0.94 : 1.0;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: on ? 10 : 8,
                vertical: on ? 6 : 8,
              ),
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // To‘p fon — oq kvadrat / yashil glow yo‘q
                  SizedBox(
                    width: on ? 46 : 36,
                    height: on ? 46 : 36,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Opacity(
                          opacity: on ? 1 : 0.55,
                          child: FootballBall(
                            size: on ? 42 : 32,
                            glow: false,
                            selected: false,
                          ),
                        ),
                        if (on)
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.32),
                            ),
                          ),
                        Icon(
                          widget.icon,
                          size: on ? 19 : 21,
                          color: Colors.white.withValues(alpha: on ? 1 : 0.88),
                          shadows: const [
                            Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (on) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.95),
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flying ball — lighter motion, short trail.
class FootballFlyLayer extends ConsumerStatefulWidget {
  const FootballFlyLayer({super.key});

  @override
  ConsumerState<FootballFlyLayer> createState() => _FootballFlyLayerState();
}

class _FootballFlyLayerState extends ConsumerState<FootballFlyLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int? _animId;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(footballNavProvider);

    if (t == null ||
        t.phase == FootballNavPhase.kick ||
        t.phase == FootballNavPhase.idle) {
      return const SizedBox.shrink();
    }

    if (_animId != t.id) {
      _animId = t.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ctrl
          ..duration = Duration(milliseconds: t.reverse ? 300 : 340)
          ..forward(from: 0);
      });
    }

    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final p = trajectoryFor(
            from: t.from,
            to: t.to,
            t: _ctrl.value,
            reverse: t.reverse,
          );
          final left = p.x * size.width - 14;
          final top = p.y * size.height - 14;
          // Less spin / less scale bounce
          final rot = _ctrl.value * 3.2;
          final scale = 1.0 + 0.08 * (1 - (2 * (_ctrl.value - 0.5).abs()));

          return Stack(
            children: [
              Positioned(
                left: left.clamp(-30, size.width - 20),
                top: top.clamp(-30, size.height - 20),
                child: Transform.scale(
                  scale: scale,
                  child: FootballBall(
                    size: 28,
                    glow: true,
                    rotation: rot,
                    trail: false,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FootballHomeStage extends ConsumerWidget {
  const FootballHomeStage({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return FootballPlayer(
      height: height,
      pose: pose,
      // Idle rasmdagi to‘p yetarli; kickda oyog‘iga tegish uchun overlay.
      showBall: phase == FootballNavPhase.kick ||
          phase == FootballNavPhase.receive,
    );
  }
}
