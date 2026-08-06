import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';

final myBookingsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(apiClientProvider).myBookings(limit: 40);
});

final myClipsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(apiClientProvider).myClips(limit: 24);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.surface2,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.firstName.isNotEmpty ? user.firstName[0] : '?',
                              style: const TextStyle(fontSize: 24),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.phone ?? '',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          if (user.position != null)
                            Text(
                              user.position!,
                              style: const TextStyle(color: AppColors.faint, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Stat(label: 'O‘yin', value: '${user.gamesPlayed}'),
                    _Stat(label: 'Gol', value: '${user.goals}'),
                    _Stat(label: 'Assist', value: '${user.assists}'),
                    _Stat(label: 'To‘p', value: '${user.topBalance}'),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Lavhalarim', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Consumer(
                  builder: (context, ref, _) {
                    final clips = ref.watch(myClipsProvider);
                    return clips.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
                      data: (page) {
                        if (page.items.isEmpty) {
                          return const Text('Hali lavha yo‘q', style: TextStyle(color: AppColors.muted));
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
                                    ? Container(
                                        color: AppColors.surface2,
                                        child: const Icon(Icons.play_circle_fill, color: AppColors.primary),
                                      )
                                    : Image.network(c.mediaUrl, fit: BoxFit.cover),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined),
                        title: const Text('Hamyon'),
                        subtitle: Text('${user.topBalance} to‘p'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/app/wallet'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Bildirishnomalar'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/app/notifications'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Mening bronlarim'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/app/bookings'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.sports_soccer_outlined),
                        title: const Text('O‘yinlar'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/app/games'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: const Text('Jamoalar'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/app/teams'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.person_add_alt_1_outlined),
                        title: const Text('Invite kod bilan qo‘shilish'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/app/teams/join'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.telegram),
                        title: const Text('Telegram bot'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => launchUrl(
                          Uri.parse(AppConstants.supportBot),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Chiqish'),
                ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.edge),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bronlarim')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myBookingsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return EmptyState(
              title: 'Bron yo‘q',
              subtitle: 'Stadion bron qiling',
              action: ElevatedButton(
                onPressed: () => context.go('/app/stadiums'),
                child: const Text('Stadionlar'),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myBookingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = page.items[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.stadium.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${formatDateShort(b.date)} · ${b.startTime} · ${b.durationHours} soat',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatPrice(b.totalPrice),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              bookingStatusLabel(b.status),
                              style: TextStyle(
                                color: b.isConfirmed
                                    ? AppColors.primary
                                    : b.isCancelled
                                        ? AppColors.danger
                                        : AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (b.isPending) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await ref.read(apiClientProvider).payBooking(b.id);
                                      ref.invalidate(myBookingsProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('To‘lash'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await ref.read(apiClientProvider).cancelBooking(b.id);
                                      ref.invalidate(myBookingsProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Bekor'),
                                ),
                              ),
                            ],
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
