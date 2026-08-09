import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Engil maydon naqshi + soft glow — yashil variety.
class PitchAtmosphere extends StatelessWidget {
  const PitchAtmosphere({
    super.key,
    this.child,
    this.showGlow = true,
    this.showGrid = true,
  });

  final Widget? child;
  final bool showGlow;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showGlow)
          Positioned(
            right: -60,
            top: 80,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      dark ? AppColors.pitchGlowDark : AppColors.pitchGlowLight,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (showGrid)
          IgnorePointer(
            child: CustomPaint(
              painter: _PitchGridPainter(
                color: (dark ? AppColors.primarySoft : AppColors.primaryDeep)
                    .withValues(
                  alpha: dark
                      ? AppColors.pitchGridAlphaDark
                      : AppColors.pitchGridAlphaLight,
                ),
              ),
              size: Size.infinite,
            ),
          ),
        if (child != null) child!,
      ],
    );
  }
}

class _PitchGridPainter extends CustomPainter {
  _PitchGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // Soft diagonal hatch
    final h = Paint()
      ..color = color.withValues(alpha: color.a * 0.7)
      ..strokeWidth = 0.8;
    for (var i = -size.height; i < size.width; i += step * 2) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        h,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PitchGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
