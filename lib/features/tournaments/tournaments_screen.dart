import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

final tournamentsProvider =
    FutureProvider.autoDispose<PageResult<Tournament>>((ref) {
  return ref.watch(apiClientProvider).listTournaments(limit: 40);
});

final tournamentDetailProvider =
    FutureProvider.autoDispose.family<TournamentDetail, int>((ref, id) {
  return ref.watch(apiClientProvider).getTournament(id);
});

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tournamentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Turnirlar')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tournamentsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const EmptyState(
              title: 'Turnir yo‘q',
              subtitle: 'Webda yangi turnir yarating',
              icon: Icons.emoji_events_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(tournamentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = page.items[i];
                return InkWell(
                  onTap: () => context.push('/app/tournaments/${t.id}'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.edge),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.emoji_events, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                '${t.format} · ${t.teamsCount}/${t.maxTeams} jamoa · ${t.status}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                              if (t.stadiumName != null)
                                Text('📍 ${t.stadiumName}', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tournamentDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Turnir')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tournamentDetailProvider(id)),
        ),
        data: (t) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${t.format} · ${t.status} · ${t.teamsCount}/${t.maxTeams}',
                  style: const TextStyle(color: AppColors.muted)),
              if (t.stadiumName != null) ...[
                const SizedBox(height: 6),
                Text('📍 ${t.stadiumName}', style: const TextStyle(color: AppColors.primary)),
              ],
              if (t.winnerTeamName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                  ),
                  child: Text('🏆 Chempion: ${t.winnerTeamName}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Setka', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (t.matches.isEmpty)
                const Text('Setka hali yo‘q — turnir boshlangach chiqadi',
                    style: TextStyle(color: AppColors.muted))
              else
                ...t.matches.map((m) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.edge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Raund ${m.round} · ${m.status}',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: Text(m.team1Name ?? 'Bye', style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text('${m.score1 ?? '·'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: Text(m.team2Name ?? '—', style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text('${m.score2 ?? '·'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                        if (m.stadiumName != null) ...[
                          const SizedBox(height: 4),
                          Text('📍 ${m.stadiumName}', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
