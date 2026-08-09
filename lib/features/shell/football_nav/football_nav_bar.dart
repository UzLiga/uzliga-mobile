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
                horizontal: on ? 12 : 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: on
                    ? const LinearGradient(
                        colors: [Color(0xFF00CC7A), Color(0xFF00E0A0)],
                      )
                    : null,
                color: on ? null : Colors.transparent,
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ball ring around icon (inactive) / solid mint pill (active)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!on)
                        Opacity(
                          opacity: 0.55,
                          child: FootballBall(size: 34, glow: false),
                        ),
                      Icon(
                        widget.icon,
                        size: 22,
                        color: on
                            ? const Color(0xFF003D26)
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                  if (on) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF003D26),
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
      showBall: pose != FootballPlayerPose.kick,
    );
  }
}
