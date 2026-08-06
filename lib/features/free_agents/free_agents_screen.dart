import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';

final freeAgentsProvider =
    FutureProvider.autoDispose.family<PageResult<FreeAgentPost>, String?>((ref, type) {
  return ref.watch(apiClientProvider).listFreeAgents(type: type, limit: 40);
});

class FreeAgentsScreen extends ConsumerStatefulWidget {
  const FreeAgentsScreen({super.key});

  @override
  ConsumerState<FreeAgentsScreen> createState() => _FreeAgentsScreenState();
}

class _FreeAgentsScreenState extends ConsumerState<FreeAgentsScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(freeAgentsProvider(_filter));
    final me = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Sherik izlash')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF052E12),
        icon: const Icon(Icons.add),
        label: const Text('E’lon'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _Chip(
                  label: 'Hammasi',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'O‘yinchi kerak',
                  selected: _filter == 'need_player',
                  onTap: () => setState(() => _filter = 'need_player'),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'O‘ynayman',
                  selected: _filter == 'want_to_play',
                  onTap: () => setState(() => _filter = 'want_to_play'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(freeAgentsProvider(_filter)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyState(
                    title: 'E’lon yo‘q',
                    subtitle: 'Birinchi bo‘lib sherik e’lon qiling',
                    icon: Icons.handshake_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(freeAgentsProvider(_filter)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final p = page.items[i];
                      final mine = me?.id == p.user.id;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.edge),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.user.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  p.needPlayer ? 'O‘yinchi kerak' : 'O‘ynayman',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.needPlayer
                                        ? AppColors.warning
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(p.comment),
                            if (p.position != null || p.locationText != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                [
                                  if (p.position != null) p.position,
                                  if (p.locationText != null) p.locationText,
                                ].join(' · '),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (p.phone != null && !mine)
                                  TextButton.icon(
                                    onPressed: () => launchUrl(
                                      Uri.parse('tel:${p.phone}'),
                                    ),
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: const Text('Qo‘ng‘iroq'),
                                  ),
                                if (mine && p.status == 'open')
                                  TextButton(
                                    onPressed: () async {
                                      await ref
                                          .read(apiClientProvider)
                                          .closeFreeAgent(p.id);
                                      ref.invalidate(freeAgentsProvider(_filter));
                                    },
                                    child: const Text('Yopish'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final comment = TextEditingController();
    final position = TextEditingController();
    final location = TextEditingController();
    var type = 'want_to_play';
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Yangi e’lon',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'want_to_play', label: Text('O‘ynayman')),
                      ButtonSegment(value: 'need_player', label: Text('Kerak')),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setModal(() => type = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Izoh',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: position,
                    decoration: const InputDecoration(
                      labelText: 'Pozitsiya (ixtiyoriy)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Joy (ixtiyoriy)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (comment.text.trim().isEmpty) return;
                            setModal(() => busy = true);
                            try {
                              await ref.read(apiClientProvider).createFreeAgent(
                                    type: type,
                                    comment: comment.text.trim(),
                                    position: position.text.trim(),
                                    locationText: location.text.trim(),
                                  );
                              ref.invalidate(freeAgentsProvider(_filter));
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            } finally {
                              setModal(() => busy = false);
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Chop etish'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    comment.dispose();
    position.dispose();
    location.dispose();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.edge,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
