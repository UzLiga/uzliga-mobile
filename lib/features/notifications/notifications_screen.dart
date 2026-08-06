import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

final notificationsProvider =
    FutureProvider.autoDispose<PageResult<AppNotification>>((ref) {
  return ref.watch(apiClientProvider).listNotifications(limit: 50);
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(apiClientProvider).unreadNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirishnomalar'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(apiClientProvider).markAllNotificationsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('Hammasi o‘qildi'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const EmptyState(
              title: 'Bildirishnoma yo‘q',
              subtitle: 'Yangi xabarlar shu yerda chiqadi',
              icon: Icons.notifications_none,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = page.items[i];
                return InkWell(
                  onTap: () async {
                    if (!n.isRead) {
                      await ref.read(apiClientProvider).markNotificationRead(n.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                    }
                    if (!context.mounted) return;
                    final link = n.link;
                    if (link != null && link.startsWith('/')) {
                      context.push(link.startsWith('/app') ? link : '/app$link');
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead
                          ? AppColors.surface2
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isRead
                            ? AppColors.edge
                            : AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: n.isRead ? null : AppColors.primary,
                                ),
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(n.body, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
