import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import 'football_nav/football_ambient.dart';
import 'football_nav/football_nav_bar.dart';
import 'football_nav/football_nav_controller.dart';

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

  Future<void> _onTap(BuildContext context, WidgetRef ref, int index) async {
    final from = navigationShell.currentIndex;
    final reduce = MediaQuery.disableAnimationsOf(context);

    await ref.read(footballNavProvider.notifier).runTo(
          from: from,
          to: index,
          reduceMotion: reduce,
          go: () {
            ref.read(shellTabIndexProvider.notifier).set(index);
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FootballAmbientBackdrop(tabIndex: idx),
          Column(
            children: [
              const OfflineBanner(),
              Expanded(child: navigationShell),
            ],
          ),
          const FootballFlyLayer(),
        ],
      ),
      bottomNavigationBar: FootballNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelect: (i) => _onTap(context, ref, i),
      ),
    );
  }
}
