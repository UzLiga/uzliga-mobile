import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
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
      appBar: AppBar(title: const Text('Profil')),
      body: userAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(userProfileProvider(userId)),
        ),
        data: (user) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(user.firstName.isNotEmpty ? user.firstName[0] : '?')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.fullName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      user.position ?? 'O‘yinchi',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Chip(label: 'Gol', value: '${user.goals}'),
                  _Chip(label: 'Assist', value: '${user.assists}'),
                  _Chip(label: 'O‘yin', value: '${user.gamesPlayed}'),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Lavhalar', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              clipsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Hali lavha yo‘q', style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: page.items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                        child: const Icon(Icons.videocam, color: AppColors.faint),
                                      ),
                                    ),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 18),
                                      ),
                                    ),
                                  ],
                                )
                              : CachedNetworkImage(imageUrl: c.mediaUrl, fit: BoxFit.cover),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
