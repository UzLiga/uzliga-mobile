import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/player_card.dart';
import '../../shared/widgets/widgets.dart';

final userProfileProvider =
    FutureProvider.autoDispose.family<User, int>((ref, id) {
  return ref.watch(apiClientProvider).getUser(id);
});

final userClipsProvider =
    FutureProvider.autoDispose.family<PageResult<MatchClip>, int>((ref, id) {
  return ref.watch(apiClientProvider).userClips(id, limit: 24);
});

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(userId));
    final clipsAsync = ref.watch(userClipsProvider(userId));

    return Scaffold(
      appBar: pcAppBar(context, title: 'Profil'),
      body: userAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(userProfileProvider(userId)),
        ),
        data: (user) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // Champions card hero
              Center(
                child: PlayerCard(
                  name: user.firstName.toUpperCase(),
                  overall: user.overall,
                  position: user.position,
                  avatarUrl: user.avatarUrl,
                  pace: user.pace,
                  shooting: user.shooting,
                  passing: user.passing,
                  dribbling: user.dribbling,
                  defending: user.defending,
                  stamina: user.stamina,
                  showFullStatsOnTap: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (user.position != null && user.position!.isNotEmpty)
                    user.position!,
                  if (user.careerTitle != null) user.careerTitle!,
                  if (user.isVerified) '✓ Verified',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2430), Color(0xFF0F141C)],
                  ),
                  border: Border.all(
                      color: const Color(0xFFE8B923).withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Attribute',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE8B923))),
                    ),
                    const SizedBox(height: 12),
                    _StatsRow(label: 'PAC', value: user.pace),
                    _StatsRow(label: 'SHO', value: user.shooting),
                    _StatsRow(label: 'PAS', value: user.passing),
                    _StatsRow(label: 'DRI', value: user.dribbling),
                    _StatsRow(label: 'DEF', value: user.defending),
                    _StatsRow(label: 'STA', value: user.stamina),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StatChip(label: 'Gol', value: '${user.goals}'),
                  const SizedBox(width: 8),
                  _StatChip(label: 'Assist', value: '${user.assists}'),
                  const SizedBox(width: 8),
                  _StatChip(label: 'O‘yin', value: '${user.gamesPlayed}'),
                ],
              ),
              const SizedBox(height: 22),
              const Text('Lavhalar',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              clipsAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const SizedBox(
                  height: 100,
                  child: LoadingView(),
                ),
                error: (e, _) => Text('$e',
                    style: const TextStyle(color: AppColors.danger)),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Hali lavha yo‘q',
                          style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: page.items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 3 / 4,
                    ),
                    itemBuilder: (_, i) {
                      final c = page.items[i];
                      return GestureDetector(
                        onTap: () => context.go('/app/reels'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: c.mediaType == 'video'
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: c.mediaUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.surface2,
                                        child: const Icon(Icons.videocam,
                                            color: AppColors.faint),
                                      ),
                                    ),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.play_circle_fill,
                                            color: Colors.white70, size: 18),
                                      ),
                                    ),
                                  ],
                                )
                              : CachedNetworkImage(
                                  imageUrl: c.mediaUrl, fit: BoxFit.cover),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? const Color(0xFFE8B923)
        : value >= 70
            ? const Color(0xFF3B82F6)
            : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (value / 99).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white12,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.edge),
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
