import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_panel.dart';

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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + bottom),
      child: GlassPanel(
        borderRadius: 28,
        strong: true,
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
                    onTap: () => onSelect(item.$1),
                  ),
                ),
            ],
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabHit> createState() => _TabHitState();
}

class _TabHitState extends State<_TabHit> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final scale = _pressed ? 0.94 : 1.0;
    final color =
        on ? Colors.white : Colors.white.withValues(alpha: 0.68);

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dumaloq soft orb — foto-to‘p emas
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: on ? 42 : 36,
                  height: on ? 42 : 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: on
                        ? const RadialGradient(
                            center: Alignment(-0.3, -0.35),
                            colors: [
                              Color(0xFF5BE0A0),
                              Color(0xFF12B76A),
                              Color(0xFF0B7A4B),
                            ],
                          )
                        : null,
                    color: on ? null : Colors.transparent,
                    border: Border.all(
                      color: on
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.transparent,
                      width: 1.4,
                    ),
                    boxShadow: on
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.icon,
                    size: on ? 22 : 22,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: on
                        ? AppColors.primarySoft
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
