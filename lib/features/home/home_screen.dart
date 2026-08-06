import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';

final homeStadiumsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(apiClientProvider).listStadiums(limit: 8, sort: '-rating');
});

final homeGamesProvider = FutureProvider.autoDispose((ref) {
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

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(homeStadiumsProvider);
          ref.invalidate(homeGamesProvider);
          await ref.read(authProvider.notifier).refreshMe();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                'Salom, $name',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  onPressed: () => context.push('/app/wallet'),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  tooltip: 'Hamyon',
                ),
                IconButton(
                  onPressed: () => context.push('/app/notifications'),
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Bildirishnomalar',
                ),
                IconButton(
                  onPressed: () => context.push('/app/bookings'),
                  icon: const Icon(Icons.calendar_month_outlined),
                  tooltip: 'Bronlar',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pillar main — book
                    InkWell(
                      onTap: () => context.go('/app/stadiums'),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF166534), Color(0xFF0B1510)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Maydon bron qilish',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Yaqiningdagi bo‘sh maydonlar — bir necha tegishda band qil.',
                              style: TextStyle(color: AppColors.muted, height: 1.35),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/app/stadiums'),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text('Boshlash'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniPillar(
                            title: 'O‘yinlar',
                            subtitle: 'Ochiq matchlar',
                            icon: Icons.sports_soccer,
                            color: AppColors.warning,
                            onTap: () => context.go('/app/games'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniPillar(
                            title: 'Jamoalar',
                            subtitle: 'Jamoa top / yarat',
                            icon: Icons.groups,
                            color: const Color(0xFF38BDF8),
                            onTap: () => context.go('/app/teams'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniPillar(
                            title: 'Turnirlar',
                            subtitle: 'Setka · chempionat',
                            icon: Icons.emoji_events,
                            color: AppColors.primary,
                            onTap: () => context.push('/app/tournaments'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniPillar(
                            title: 'Sherik',
                            subtitle: 'Free agent',
                            icon: Icons.handshake_outlined,
                            color: const Color(0xFFA78BFA),
                            onTap: () => context.push('/app/free-agents'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Tavsiya etilgan maydonlar',
                      actionLabel: 'Hammasi',
                      onAction: () => context.go('/app/stadiums'),
                    ),
                  ],
                ),
              ),
            ),
            stadiums.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.all(24), child: LoadingView()),
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
                        child: Text('Maydonlar yuklanmoqda…',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: SizedBox(
                        height: 210,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: page.items.length.clamp(0, 6),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: SectionHeader(
                  title: 'Ochiq o‘yinlar',
                  actionLabel: 'Hammasi',
                  onAction: () => context.go('/app/games'),
                ),
              ),
            ),
            games.when(
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final g = page.items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          onTap: () => context.push('/app/games/${g.id}'),
                          title: Text(
                            g.stadium.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${formatDateShort(g.date)} · ${g.startTime} · ${g.format} · ${g.playersCount}/${g.maxPlayers}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _MiniPillar extends StatelessWidget {
  const _MiniPillar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.edge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
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
                  if (badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Color(0xFF052E12),
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
              padding: const EdgeInsets.all(10),
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
