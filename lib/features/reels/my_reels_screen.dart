import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../profile/profile_screen.dart';

final manageClipsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).myClips(limit: 60);
});

class MyReelsManageScreen extends ConsumerStatefulWidget {
  const MyReelsManageScreen({super.key});

  @override
  ConsumerState<MyReelsManageScreen> createState() =>
      _MyReelsManageScreenState();
}

class _MyReelsManageScreenState extends ConsumerState<MyReelsManageScreen> {
  Future<void> _openComposer() async {
    final ok = await context.push<bool>('/app/clip-composer');
    if (ok == true) {
      ref.invalidate(manageClipsProvider);
      ref.invalidate(myClipsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(manageClipsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: pcAppBar(context, title: 'Mening reels'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: AppColors.lime,
        foregroundColor: const Color(0xFF052E12),
        icon: const Icon(Icons.add),
        label: const Text('Yuklash'),
      ),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(manageClipsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return EmptyState(
              title: 'Lavha yo‘q',
              subtitle: 'Match Moment yaratib birinchi reelsni joylang',
              action: ElevatedButton.icon(
                onPressed: _openComposer,
                icon: const Icon(Icons.sports_soccer),
                label: const Text('Match Moment'),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(manageClipsProvider),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: page.items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 3 / 4,
              ),
              itemBuilder: (_, i) {
                final c = page.items[i];
                final thumb = c.posterUrl ?? c.mediaUrl;
                return GestureDetector(
                  onTap: () => _openActions(context, ref, c),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PcNetworkImage(url: thumb),
                        if (c.mediaType == 'video')
                          const Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.play_circle_fill,
                                  color: Colors.white70, size: 18),
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

  Future<void> _openActions(
      BuildContext context, WidgetRef ref, MatchClip c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Caption tahrirlash'),
              onTap: () async {
                Navigator.pop(ctx);
                await _editCaption(context, ref, c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie_filter_outlined),
              title: const Text('Reelsda ochish'),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/app/reels');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('O‘chirish',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('O‘chirish'),
                    content: const Text('Bu lavha o‘chirilsinmi?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Yo‘q')),
                      TextButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Ha')),
                    ],
                  ),
                );
                if (ok != true) return;
                await ref.read(apiClientProvider).deleteClip(c.id);
                ref.invalidate(manageClipsProvider);
                ref.invalidate(myClipsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCaption(
      BuildContext context, WidgetRef ref, MatchClip c) async {
    final ctrl = TextEditingController(text: c.caption ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Caption'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Matn…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Bekor')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Saqlash')),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(apiClientProvider)
        .patchClip(c.id, caption: ctrl.text.trim());
    ref.invalidate(manageClipsProvider);
    ref.invalidate(myClipsProvider);
  }
}
