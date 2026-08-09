import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/league_table.dart';
import '../../shared/widgets/tournament_bracket.dart';
import '../../shared/widgets/widgets.dart';

final tournamentsProvider =
    FutureProvider<PageResult<Tournament>>((ref) {
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
      appBar: pcAppBar(context, title: 'Turnirlar'),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tournamentsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const EmptyState(
              title: 'Turnir yo‘q',
              subtitle: 'Tez orada yangi turnirlar chiqadi',
              icon: Icons.emoji_events_outlined,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(tournamentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final t = page.items[i];
                final fill = t.maxTeams == 0
                    ? 0.0
                    : (t.teamsCount / t.maxTeams).clamp(0.0, 1.0);
                return InkWell(
                  onTap: () => context.push('/app/tournaments/${t.id}'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF163528), Color(0xFF0F1F18)],
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.emoji_events,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      t.format,
                                      if (t.stadiumName != null) t.stadiumName!,
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t.status,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: fill,
                            minHeight: 6,
                            backgroundColor: Colors.white12,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${t.teamsCount}/${t.maxTeams} jamoa',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

class TournamentDetailScreen extends ConsumerStatefulWidget {
  const TournamentDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> {
  bool _joining = false;

  Future<void> _join() async {
    final teams = await ref.read(apiClientProvider).myTeams(limit: 30);
    if (!mounted) return;
    if (teams.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval jamoa yarating yoki qo‘shiling')),
      );
      return;
    }
    final teamId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Jamoani tanlang',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            ...teams.items.map(
              (t) => ListTile(
                title: Text(t.name),
                subtitle: Text('${t.membersCount} a’zo'),
                onTap: () => Navigator.pop(ctx, t.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (teamId == null || !mounted) return;
    setState(() => _joining = true);
    try {
      await ref.read(apiClientProvider).joinTournament(
            tournamentId: widget.id,
            teamId: teamId,
          );
      ref.invalidate(tournamentDetailProvider(widget.id));
      ref.invalidate(tournamentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turnirga yozildingiz')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tournamentDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: pcAppBar(context, title: 'Turnir'),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tournamentDetailProvider(widget.id)),
        ),
        data: (t) {
          final canJoin = t.status == 'open' || t.status == 'registration';
          final fill = t.maxTeams == 0
              ? 0.0
              : (t.teamsCount / t.maxTeams).clamp(0.0, 1.0);
          final statusLabel = switch (t.status) {
            'live' || 'in_progress' || 'ongoing' => 'LIVE',
            'finished' || 'completed' => 'COMPLETED',
            _ => 'UPCOMING',
          };
          final isLive = statusLabel == 'LIVE';
          final matchesCount = t.matches.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // Hero
              Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.6),
                    radius: 1.2,
                    colors: [
                      Color(0xFF163528),
                      Color(0xFF07110B),
                      Color(0xFF050807),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.lime.withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.lime.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.lime.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(Icons.emoji_events_rounded,
                              color: AppColors.lime),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: isLive
                                ? AppColors.lime.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.06),
                            border: Border.all(
                              color: isLive
                                  ? AppColors.lime.withValues(alpha: 0.55)
                                  : AppColors.edge,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLive) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.lime,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  color: isLive
                                      ? AppColors.lime
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t.teamsCount} JAMOA  ·  $matchesCount MATCH  ·  1 CHAMPION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                    if (t.stadiumName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        t.stadiumName!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: fill,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        color: AppColors.lime,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t.teamsCount}/${t.maxTeams} jamoa · ${t.format}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (t.winnerTeamName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.lime.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.lime.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHAMPIONS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: AppColors.lime.withValues(alpha: 0.9),
                              ),
                            ),
                            Text(
                              t.winnerTeamName!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (canJoin) ...[
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: const Color(0xFF052E12),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _joining ? null : _join,
                  child: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Jamoa bilan qo‘shilish',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                'BRACKET',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.6,
                  color: AppColors.lime,
                ),
              ),
              const SizedBox(height: 10),
              TournamentBracketView(
                matches: t.matches,
                maxTeams: t.maxTeams,
                onTeamTap: (id) => context.push('/app/teams/$id'),
              ),
              const SizedBox(height: 22),
              const Text(
                'STANDINGS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.6,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              LeagueTableView(matches: t.matches),
            ],
          );
        },
      ),
    );
  }
}
