import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
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
      appBar: pcAppBar(
        context,
        title: 'Bildirishnomalar',
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
                final isTicket = n.type.contains('book') ||
                    n.title.toLowerCase().contains('bron') ||
                    (n.link?.contains('booking') ?? false);
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
                      gradient: isTicket
                          ? const LinearGradient(
                              colors: [Color(0xFF1A2A1F), Color(0xFF0B1510)],
                            )
                          : null,
                      color: isTicket
                          ? null
                          : (n.isRead
                              ? AppColors.surface2
                              : AppColors.primary.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isTicket
                            ? AppColors.gold.withValues(alpha: 0.45)
                            : (n.isRead
                                ? AppColors.edge
                                : AppColors.primary.withValues(alpha: 0.35)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isTicket) ...[
                              const Icon(Icons.confirmation_number,
                                  size: 18, color: AppColors.gold),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isTicket
                                      ? AppColors.gold
                                      : (n.isRead ? null : AppColors.primary),
                                ),
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isTicket
                                      ? AppColors.gold
                                      : AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(n.body,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                        if (isTicket) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Ticket · QR Bronlarimda',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
