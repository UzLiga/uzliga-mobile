import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import 'football_nav/football_nav_bar.dart';

/// Bottom-nav selected index — Reels pauses when not visible.
final shellTabIndexProvider =
    NotifierProvider<ShellTabIndexNotifier, int>(ShellTabIndexNotifier.new);

class ShellTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(WidgetRef ref, int index) {
    ref.read(shellTabIndexProvider.notifier).set(index);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = navigationShell.currentIndex;
    if (ref.read(shellTabIndexProvider) != idx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(shellTabIndexProvider.notifier).set(idx);
      });
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.bg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xFF061A12),
                        AppColors.bg,
                        Color(0xFF03110C),
                      ]
                    : const [
                        Color(0xFFF4FBF7),
                        AppColors.lightBg,
                        Color(0xFFE8F5EE),
                      ],
              ),
            ),
          ),
          Positioned(
            right: -40,
            top: MediaQuery.sizeOf(context).height * 0.18,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: dark ? 0.14 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              const OfflineBanner(),
              Expanded(child: navigationShell),
            ],
          ),
        ],
      ),
      bottomNavigationBar: FootballNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelect: (i) => _onTap(ref, i),
      ),
    );
  }
}
