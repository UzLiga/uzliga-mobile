import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Consistent AppBar with reliable back → previous or home.
PreferredSizeWidget pcAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  bool implyLeading = true,
}) {
  final canPop = context.canPop();
  return AppBar(
    title: Text(title),
    actions: actions,
    automaticallyImplyLeading: false,
    leading: implyLeading
        ? IconButton(
            tooltip: 'Orqaga',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              if (canPop) {
                context.pop();
              } else {
                context.go('/app');
              }
            },
          )
        : null,
  );
}

/// Floating back chip for full-bleed screens (map / sliver heroes).
class PcBackChip extends StatelessWidget {
  const PcBackChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8),
        child: Material(
          color: AppColors.bg.withValues(alpha: 0.72),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: 'Orqaga',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.ink,
            onPressed: onTap ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/app');
                  }
                },
          ),
        ),
      ),
    );
  }
}
