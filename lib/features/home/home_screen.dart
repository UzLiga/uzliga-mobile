import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';
import '../shell/football_nav/football_nav_controller.dart';
import '../shell/shell_screen.dart';

final homeStadiumsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).listStadiums(limit: 8, sort: '-rating');
});

final homeGamesProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).listGames(status: 'open', limit: 5);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final stadiums = ref.watch(homeStadiumsProvider);
    final games = ref.watch(homeGamesProvider);
    final name = auth.user?.firstName ?? 'Chempion';
    final heroUrl = stadiums.maybeWhen(
      data: (p) => p.items.isNotEmpty ? p.items.first.imageUrl : null,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(homeStadiumsProvider);
          ref.invalidate(homeGamesProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHero(
                name: name,
                heroImageUrl: heroUrl,
                onWallet: () => context.push('/app/wallet'),
                onNotif: () => context.push('/app/notifications'),
                onBook: () => context.push('/app/stadiums'),
                onPlay: () => context.go('/app/games'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  children: [
                    _NavChip(
                      icon: Icons.sports_soccer,
                      label: 'O‘yinlar',
                      onTap: () {
                        final shell = ref.read(shellTabIndexProvider);
                        ref.read(footballNavProvider.notifier).runTo(
                              from: shell,
                              to: 1,
                              reduceMotion:
                                  MediaQuery.disableAnimationsOf(context),
                              go: () => context.go('/app/games'),
                            );
                      },
                    ),
                    _NavChip(
                      icon: Icons.groups_outlined,
                      label: 'Jamoalar',
                      onTap: () => context.push('/app/teams'),
                    ),
                    _NavChip(
                      icon: Icons.emoji_events_outlined,
                      label: 'Turnir',
                      onTap: () => context.push('/app/tournaments'),
                    ),
                    _NavChip(
                      icon: Icons.handshake_outlined,
                      label: 'Sherik',
                      onTap: () => context.push('/app/free-agents'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: SectionHeader(
                  title: 'Yaqin maydonlar',
                  actionLabel: 'Hammasi',
                  onAction: () => context.push('/app/stadiums'),
                ),
              ),
            ),
            stadiums.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingView(),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(homeStadiumsProvider),
                ),
              ),
              data: (page) => page.items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Maydon topilmadi',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: SizedBox(
                        height: 228,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: page.items.length.clamp(0, 8),
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            return _StadiumCard(
                              stadium: page.items[i],
                              badge: i == 0 ? 'Top' : null,
                            );
                          },
                        ),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                child: SectionHeader(
                  title: 'Ochiq o‘yinlar',
                  actionLabel: 'Hammasi',
                  onAction: () => context.go('/app/games'),
                ),
              ),
            ),
            games.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const SliverToBoxAdapter(child: LoadingView()),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(homeGamesProvider),
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Hozircha ochiq o‘yin yo‘q',
                        icon: Icons.sports_soccer,
                      ),
                    ),
                  );
                }
                return SliverList.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = page.items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _GameRow(game: g),
                    );
                  },
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed match-night hero — brand first, one CTA group.
class _HomeHero extends StatefulWidget {
  const _HomeHero({
    required this.name,
    required this.onWallet,
    required this.onNotif,
    required this.onBook,
    required this.onPlay,
    this.heroImageUrl,
  });

  final String name;
  final String? heroImageUrl;
  final VoidCallback onWallet;
  final VoidCallback onNotif;
  final VoidCallback onBook;
  final VoidCallback onPlay;

  @override
  State<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<_HomeHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final h = MediaQuery.sizeOf(context).height;
    // First viewport composition (~78% screen)
    final heroH = (h * 0.78).clamp(420.0, 620.0);

    return SizedBox(
      height: heroH,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed pitch / stadium
          if (widget.heroImageUrl != null && widget.heroImageUrl!.isNotEmpty)
            PcNetworkImage(url: widget.heroImageUrl!)
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF00A864),
                    Color(0xFF041510),
                    Color(0xFF02100C),
                  ],
                ),
              ),
            ),
          // Atmosphere overlays
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66041510),
                  Color(0x22041510),
                  Color(0xE6041510),
                ],
                stops: [0, 0.35, 1],
              ),
            ),
          ),
          // Cyber Mint wash
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final a = 0.10 + _pulse.value * 0.12;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.65, -0.15),
                    radius: 1.05,
                    colors: [
                      AppColors.primary.withValues(alpha: a),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
          // Top chrome
          Positioned(
            left: 8,
            right: 8,
            top: top + 4,
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: widget.onWallet,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  color: Colors.white70,
                ),
                IconButton(
                  onPressed: widget.onNotif,
                  icon: const Icon(Icons.notifications_outlined),
                  color: Colors.white70,
                ),
              ],
            ),
          ),
          // Brand + copy + CTA — bottom third of hero
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAYZON',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                    height: 1,
                    color: AppColors.primary,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Salom, ${widget.name}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Maydon bron qiling yoki ochiq o‘yinga qo‘shiling.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: widget.onBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: const Color(0xFF003D26),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Bron qilish',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: widget.onPlay,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.65),
                          ),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'O‘yin',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.edge),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final fill = game.maxPlayers == 0
        ? 0.0
        : (game.playersCount / game.maxPlayers).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/app/games/${game.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF163528), Color(0xFF0B1510)],
            ),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: PcNetworkImage(url: game.stadium.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.stadium.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatDateShort(game.date)} · ${game.startTime} · ${game.format}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: fill,
                        minHeight: 4,
                        backgroundColor: Colors.white12,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${game.playersCount}/${game.maxPlayers}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({required this.stadium, this.badge});
  final Stadium stadium;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/app/stadiums/${stadium.id}'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.edge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PcNetworkImage(url: stadium.imageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA0B1510)],
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Color(0xFF1A1000),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stadium.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stadium.district} · ${formatPrice(stadium.pricePerHour)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
