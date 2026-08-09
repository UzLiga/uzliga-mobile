import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/booking_ticket.dart';
import '../../shared/widgets/player_card.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';

final myBookingsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).myBookings(limit: 40);
});

final myClipsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).myClips(limit: 24);
});

final myTeamsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).myTeams(limit: 10);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final clips = ref.watch(myClipsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: user == null
          ? const LoadingView()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref.read(authProvider.notifier).refreshMe();
                ref.invalidate(myClipsProvider);
                ref.invalidate(myTeamsProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    title: const Text('Profil'),
                    actions: [
                      IconButton(
                        tooltip: isDark ? 'Yorug‘ rejim' : 'Qorong‘u rejim',
                        onPressed: () =>
                            ref.read(themeModeProvider.notifier).toggle(),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                                spreadRadius: -8,
                              ),
                            ],
                          ),
                          child: const SizedBox(
                            width: double.infinity,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onLongPress: () => _openEdit(context, ref, user),
                          child: _HeroHeader(user: user),
                        ),
                        const SizedBox(height: 16),
                        _PremiumFifaSection(user: user),
                        const SizedBox(height: 16),
                        _MyPositionSection(user: user),
                        const SizedBox(height: 16),
                        _Achievements(user: user),
                        const SizedBox(height: 16),
                        if (user.referralCode != null &&
                            user.referralCode!.isNotEmpty) ...[
                          _ReferralCard(code: user.referralCode!),
                          const SizedBox(height: 16),
                        ],
                        const _SectionTitle(title: 'Tezkor'),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            try {
                              await ref.read(apiClientProvider).setAvailability({
                                'status': 'ready',
                                'hours': 2,
                                'note': '1 soat ichida yaqin stadionga boraman',
                                'radius_km': 8,
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Status: Bora olaman (2 soat)'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.near_me_outlined),
                          label: const Text('Bora olaman'),
                        ),
                        const SizedBox(height: 8),
                        _QuickGrid(
                          items: [
                            _QuickItem(
                              icon: Icons.calendar_month_outlined,
                              label: 'Bronlarim',
                              onTap: () => context.push('/app/bookings'),
                            ),
                            _QuickItem(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Hamyonim',
                              onTap: () => context.push('/app/wallet'),
                            ),
                            _QuickItem(
                              icon: Icons.groups_outlined,
                              label: 'Jamoam',
                              onTap: () => context.push('/app/teams'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MenuCard(
                          children: [
                            _MenuTile(
                              icon: Icons.telegram,
                              title: 'Telegram bot',
                              trailing: const Icon(Icons.open_in_new, size: 18),
                              onTap: () => launchUrl(
                                Uri.parse(AppConstants.supportBot),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        clips.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (page) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: _SectionTitle(
                                          title: '🎬 MY FOOTBALL MOMENTS'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          context.push('/app/clip-composer'),
                                      icon: const Icon(Icons.add_circle_outline,
                                          size: 18),
                                      label: const Text('Yuklash'),
                                    ),
                                  ],
                                ),
                                if (page.items.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          context.push('/app/clip-composer'),
                                      icon: const Icon(Icons.sports_soccer),
                                      label: const Text('Match Moment yaratish'),
                                    ),
                                  )
                                else ...[
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: page.items.length.clamp(0, 9),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 6,
                                      crossAxisSpacing: 6,
                                      childAspectRatio: 9 / 16,
                                    ),
                                    itemBuilder: (context, i) {
                                      final c = page.items[i];
                                      final thumb =
                                          c.posterUrl ?? c.mediaUrl;
                                      return GestureDetector(
                                        onTap: () =>
                                            context.push('/app/my-reels'),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: PcNetworkImage(url: thumb),
                                        ),
                                      );
                                    },
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          context.push('/app/my-reels'),
                                      child: const Text('Boshqarish'),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Chiqish'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Playzon ${AppConstants.appVersion}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.faint,
                            fontSize: 11,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref, User user) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditProfileSheet(user: user),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil yangilandi')),
      );
    }
  }
}

String _positionCode(String? position) {
  final p = (position ?? '').toUpperCase().trim();
  if (p.isEmpty) return 'CM';
  if (p.length <= 3) return p;
  if (p.contains('DARVOZA') || p.contains('GK')) return 'GK';
  if (p.contains('HIMOY') || p.contains('DEF')) return 'CB';
  if (p.contains('YARIM')) return 'CM';
  if (p.contains('HUJUM') || p.contains('ST')) return 'ST';
  return p.substring(0, math.min(3, p.length));
}

String _positionLine(String? position) {
  final code = _positionCode(position);
  return '$code · ${PlayerCard.positionLabelUz(position)}';
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final premium = user.isPremium;
    final ring = premium ? AppColors.gold : AppColors.lime;
    final frame = premium
        ? AppColors.gold.withValues(alpha: 0.75)
        : AppColors.lime.withValues(alpha: 0.2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 1.15,
          colors: premium
              ? const [
                  Color(0xFF3A2A0C),
                  Color(0xFF1A1408),
                  Color(0xFF0A0905),
                ]
              : const [
                  Color(0xFF163528),
                  Color(0xFF07110B),
                  Color(0xFF050807),
                ],
        ),
        border: Border.all(color: frame, width: premium ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: premium ? 0.28 : 0.08),
            blurRadius: premium ? 32 : 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'FUTBOL IDENTITETI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: ring.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: premium ? 3 : 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: ring.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? PcNetworkImage(
                          url: user.avatarUrl!,
                          memCacheWidth: 208,
                          memCacheHeight: 208,
                        )
                      : Container(
                          color: AppColors.surface2,
                          alignment: Alignment.center,
                          child: Text(
                            user.firstName.isNotEmpty ? user.firstName[0] : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ),
              if (user.isVerified)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF050807),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified,
                        color: premium ? AppColors.gold : AppColors.lime,
                        size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_positionLine(user.position)}  ·  ${user.overall} OVR',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink.withValues(alpha: 0.75),
            ),
          ),
          if (premium) ...[
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium, color: AppColors.gold, size: 16),
                SizedBox(width: 4),
                Text('PREMIUM',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1,
                    )),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: '${user.goals}',
                  label: 'Gollar',
                  icon: '⚽',
                  emphasize: true,
                  accent: premium ? AppColors.gold : AppColors.lime,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '${user.assists}',
                  label: 'Uzatmalar',
                  icon: '🎯',
                  emphasize: true,
                  accent: premium ? AppColors.gold : AppColors.lime,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: user.rating.toStringAsFixed(1),
                  label: 'Reyting',
                  icon: '⭐',
                  accent: AppColors.lime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
    this.emphasize = false,
    this.accent = AppColors.lime,
  });
  final String value;
  final String label;
  final String icon;
  final bool emphasize;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$icon $value',
            style: TextStyle(
              fontSize: emphasize ? 24 : 16,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1.05,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: emphasize ? 12 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: emphasize ? AppColors.ink.withValues(alpha: 0.8) : AppColors.muted,
            )),
      ],
    );
  }
}

class _PremiumFifaSection extends ConsumerWidget {
  const _PremiumFifaSection({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!user.isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A2110), Color(0xFF0B1510)],
          ),
          border: Border.all(
            color: const Color(0xFFE8B923).withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium, color: Color(0xFFE8B923)),
                SizedBox(width: 8),
                Text(
                  'Premium · FIFA karta',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'FIFA karta va karyera (flip) — faqat Premium da.\n'
              'O‘yin · gol · uzatma · sariq/qizil · reyting orqa tomonda.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/app/premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF1A1000),
                ),
                icon: const Icon(Icons.lock_open),
                label: const Text('Premium ochish'),
              ),
            ),
          ],
        ),
      );
    }
    return _FifaFlipCard(user: user);
  }
}

class _FifaFlipCard extends StatefulWidget {
  const _FifaFlipCard({required this.user});
  final User user;

  @override
  State<_FifaFlipCard> createState() => _FifaFlipCardState();
}

class _FifaFlipCardState extends State<_FifaFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_ctrl.isAnimating) return;
    HapticFeedback.selectionClick();
    if (_ctrl.value < 0.5) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 180) return;
    // o'ng→chap yoki chap→o'ng — flip
    _flip();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_ctrl.value);
        final angle = t * math.pi;
        final showBack = angle > math.pi / 2;
        return Column(
          children: [
            GestureDetector(
              onTap: _flip,
              onHorizontalDragEnd: _onDragEnd,
              child: SizedBox(
                height: 460,
                width: double.infinity,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: showBack
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _CareerBack(user: user),
                        )
                      : _FifaFront(user: user),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              showBack
                  ? 'Surish yoki bosish — FIFA karta'
                  : 'Surish yoki bosish — karyera',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

class _FifaFront extends StatelessWidget {
  const _FifaFront({required this.user});
  final User user;

  Color get _tier {
    if (user.overall >= 80) return const Color(0xFFE8B923);
    if (user.overall >= 70) return const Color(0xFF3B82F6);
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _tier.withValues(alpha: 0.35),
            const Color(0xFF0B1510),
            const Color(0xFF050D14),
          ],
        ),
        border: Border.all(color: _tier.withValues(alpha: 0.65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _tier.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'FIFA karta',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const Spacer(),
              Icon(Icons.flip, size: 16, color: _tier),
              const SizedBox(width: 4),
              Text(
                'Aylantirish',
                style: TextStyle(
                  color: _tier,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
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
                profile: true,
                showFullStatsOnTap: false,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _MiniAttrs(user: user),
        ],
      ),
    );
  }
}

class _MiniAttrs extends StatelessWidget {
  const _MiniAttrs({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final attrs = [
      ('PAC', user.pace),
      ('SHO', user.shooting),
      ('PAS', user.passing),
      ('DRI', user.dribbling),
      ('DEF', user.defending),
      ('STA', user.stamina),
    ];
    return Row(
      children: [
        for (final a in attrs)
          Expanded(
            child: Column(
              children: [
                Text(
                  '${a.$2}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFFE8B923),
                  ),
                ),
                Text(
                  a.$1,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CareerBack extends StatelessWidget {
  const _CareerBack({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final title = user.careerTitle ?? 'Yangi o‘yinchi';
    final progress = user.careerProgress.clamp(0.0, 1.0);
    final toNext = user.careerGamesToNext;
    final discount = user.careerDiscountPercent;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A1F), Color(0xFF0B1510), Color(0xFF07100C)],
        ),
        border: Border.all(
          color: const Color(0xFFE8B923).withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech, color: Color(0xFFE8B923), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Karyera',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B923).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Daraja ${user.careerLevel}',
                  style: const TextStyle(
                    color: Color(0xFFE8B923),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            discount > 0
                ? 'Do‘konlarda $discount% chegirma'
                : (user.careerShopHint ?? 'O‘yin o‘ynab daraja oshiring'),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              color: const Color(0xFFE8B923),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            toNext > 0
                ? 'Keyingi darajaga $toNext o‘yin'
                : 'Maksimal daraja',
            style: const TextStyle(color: AppColors.faint, fontSize: 11),
          ),
          const Spacer(),
          Row(
            children: [
              _CareerStat(
                label: 'O‘yinlar',
                value: '${user.gamesPlayed}',
                color: Colors.white,
              ),
              _CareerStat(
                label: 'Gollar',
                value: '${user.goals}',
                color: const Color(0xFFE8B923),
              ),
              _CareerStat(
                label: 'Uzatmalar',
                value: '${user.assists}',
                color: const Color(0xFF3B82F6),
              ),
              _CareerStat(
                label: 'Reyting',
                value: user.rating.toStringAsFixed(1),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _CareerStat(
                label: 'Sariq',
                value: '${user.yellowCards}',
                color: const Color(0xFFFACC15),
              ),
              _CareerStat(
                label: 'Qizil',
                value: '${user.redCards}',
                color: const Color(0xFFEF4444),
              ),
              _CareerStat(
                label: 'OVR',
                value: '${user.overall}',
                color: const Color(0xFFE8B923),
              ),
              _CareerStat(
                label: 'Pozitsiya',
                value: _positionCode(user.position),
                color: Colors.white70,
              ),
            ],
          ),
          if (user.heightCm != null ||
              user.weightKg != null ||
              user.preferredFoot != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (user.heightCm != null) '${user.heightCm} cm',
                if (user.weightKg != null) '${user.weightKg} kg',
                if (user.preferredFoot != null)
                  user.preferredFoot == 'left'
                      ? 'Chap oyoq'
                      : user.preferredFoot == 'right'
                          ? 'O‘ng oyoq'
                          : 'Ikkalasi',
              ].join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CareerStat extends StatelessWidget {
  const _CareerStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPositionSection extends StatelessWidget {
  const _MyPositionSection({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final code = _positionCode(user.position);
    final label = PlayerCard.positionLabelUz(user.position);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚽ Mening pozitsiyam',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.0,
            color: AppColors.lime,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$code · $label',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        PitchFormation.fromUsers(
          players: [user],
          formatSize: 7,
          onPlayerTap: (_) {},
        ),
      ],
    );
  }
}

class _Achievements extends ConsumerWidget {
  const _Achievements({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(myTeamsProvider);
    final teams = teamsAsync.maybeWhen(
      data: (page) => page.items,
      orElse: () => const <Team>[],
    );
    final isCaptain = teams.any((t) => t.captainId == user.id);

    final items = [
      _Ach(
        'Premium kubogi',
        user.isPremium ? 'Ochilgan' : 'Yopiq',
        Icons.workspace_premium,
        user.isPremium,
        AppColors.gold,
      ),
      _Ach(
        'Faol o‘yinchi',
        user.gamesPlayed >= 3 ? '${user.gamesPlayed} o‘yin' : '3+ o‘yin',
        Icons.sports_soccer,
        user.gamesPlayed >= 3,
        AppColors.lime,
      ),
      if (isCaptain)
        const _Ach(
          'Sardorlik',
          'Jamoa sardori',
          Icons.star,
          true,
          AppColors.gold,
        ),
      const _Ach(
        'Turnir ishtiroki',
        'Tez orada',
        Icons.emoji_events_outlined,
        false,
        AppColors.muted,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏆 Kuboklar',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.0,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1510), Color(0xFF0C100D)],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final a in items.take(4))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(
                          opacity: a.got ? 1 : 0.42,
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                    bottom: Radius.circular(4),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: a.got
                                        ? [
                                            a.color.withValues(alpha: 0.95),
                                            a.color.withValues(alpha: 0.35),
                                          ]
                                        : [
                                            Colors.white24,
                                            Colors.white10,
                                          ],
                                  ),
                                  boxShadow: a.got
                                      ? [
                                          BoxShadow(
                                            color:
                                                a.color.withValues(alpha: 0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  a.got ? a.icon : Icons.lock_outline,
                                  color: a.got
                                      ? const Color(0xFF1A1000)
                                      : AppColors.faint,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      a.got ? AppColors.ink : AppColors.faint,
                                ),
                              ),
                              Text(
                                a.sub,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: a.got
                                      ? AppColors.muted
                                      : AppColors.faint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6B4E2E).withValues(alpha: 0.9),
                      const Color(0xFF3D2A16),
                      const Color(0xFF6B4E2E).withValues(alpha: 0.9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ach {
  const _Ach(this.label, this.sub, this.icon, this.got, [this.color = AppColors.lime]);
  final String label;
  final String sub;
  final IconData icon;
  final bool got;
  final Color color;
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edge),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Referral kod',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(code, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod nusxalandi')),
              );
            },
            icon: const Icon(Icons.copy, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _QuickItem {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.items});
  final List<_QuickItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return Material(
          color: Theme.of(context).cardTheme.color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});
  final User user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  static const _positions = [
    'GK',
    'CB',
    'LB',
    'RB',
    'CDM',
    'CM',
    'CAM',
    'LW',
    'RW',
    'ST',
  ];

  late final TextEditingController _name;
  late final TextEditingController _birthYear;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late String? _position;
  late String? _gender;
  late String? _foot;
  String? _localAvatarPath;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u.fullName);
    _position = u.position;
    _gender = u.gender;
    _foot = u.preferredFoot;
    _birthYear = TextEditingController(text: u.birthYear?.toString() ?? '');
    _height = TextEditingController(text: u.heightCm?.toString() ?? '');
    _weight = TextEditingController(text: u.weightKg?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _localAvatarPath = x.path;
      _uploadingAvatar = true;
    });
    try {
      await ref.read(apiClientProvider).uploadAvatar(
            filePath: x.path,
            fileName: x.name,
          );
      await ref.read(authProvider.notifier).refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rasm yangilandi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ism kamida 2 belgi')),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'full_name': name,
      'position': _position,
      'gender': _gender,
      'preferred_foot': _foot,
    };
    final by = int.tryParse(_birthYear.text.trim());
    if (by != null) payload['birth_year'] = by;
    final h = int.tryParse(_height.text.trim());
    if (h != null) payload['height_cm'] = h;
    final w = int.tryParse(_weight.text.trim());
    if (w != null) payload['weight_kg'] = w;

    final ok = await ref.read(authProvider.notifier).updateProfile(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Xatolik')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final avatar = _localAvatarPath != null
        ? null
        : widget.user.avatarUrl;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.edge,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Profilni tahrirlash',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ism, rasm, pozitsiya, jismoniy ma’lumot — FIFA attrs o‘yinlardan.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAvatar,
                child: Stack(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: _localAvatarPath != null
                            ? Image.file(
                                File(_localAvatarPath!),
                                fit: BoxFit.cover,
                              )
                            : (avatar != null && avatar.isNotEmpty
                                ? PcNetworkImage(
                                    url: avatar,
                                    memCacheWidth: 176,
                                  )
                                : Container(
                                    color: AppColors.surface2,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.person, size: 40),
                                  )),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _uploadingAvatar
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF052E12),
                                ),
                              )
                            : const Icon(Icons.camera_alt,
                                size: 14, color: Color(0xFF052E12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'To‘liq ism'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _positions.contains(_position) ? _position : null,
              decoration: const InputDecoration(labelText: 'Pozitsiya'),
              items: _positions
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text('$p · ${PlayerCard.positionLabelUz(p)}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _position = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  _gender == 'male' || _gender == 'female' ? _gender : null,
              decoration: const InputDecoration(labelText: 'Jins'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Erkak')),
                DropdownMenuItem(value: 'female', child: Text('Ayol')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: ['left', 'right', 'both'].contains(_foot)
                  ? _foot
                  : null,
              decoration: const InputDecoration(labelText: 'Asosiy oyoq'),
              items: const [
                DropdownMenuItem(value: 'right', child: Text('O‘ng')),
                DropdownMenuItem(value: 'left', child: Text('Chap')),
                DropdownMenuItem(value: 'both', child: Text('Ikkalasi')),
              ],
              onChanged: (v) => setState(() => _foot = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Bo‘y (cm)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _weight,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Vazn (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthYear,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tug‘ilgan yil'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Saqlash'),
            ),
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
      appBar: pcAppBar(
        context,
        title: 'Bronlarim',
      ),
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
                onPressed: () => context.push('/app/stadiums'),
                child: const Text('Stadionlar'),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myBookingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final b = page.items[i];
                final deposit = b.stadium.depositFor(b.totalPrice);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BookingTicket.fromBooking(b, compact: true),
                    if (b.stadium.payoutCardMasked != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Egasi kartasi ${b.stadium.payoutCardMasked}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (b.isConfirmed || b.isPending) ...[
                      const SizedBox(height: 10),
                      if (b.isConfirmed)
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final qr = await ref
                                  .read(apiClientProvider)
                                  .bookingQr(b.id);
                              if (!context.mounted) return;
                              await showBookingTicketSheet(
                                context,
                                title: 'Kirish ticketi',
                                actionLabel: 'Yopish',
                                ticket: BookingTicket.fromBooking(b,
                                    qrPayload: qr),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: const Color(0xFF1A1000),
                          ),
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('QR ticket'),
                        ),
                      if (b.isPending) ...[
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(apiClientProvider)
                                  .payBooking(b.id);
                              ref.invalidate(myBookingsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          child: Text('Zakalat · ${formatPrice(deposit)}'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: const Text('Bronni bekor qilish?'),
                              content: const Text(
                                'Qoidalar:\n'
                                '• ≥24 soat oldin — 100% qaytarish\n'
                                '• 2–24 soat — 50%\n'
                                '• <2 soat — qaytarish yo‘q',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Yo‘q'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Bekor qilish'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          try {
                            final res = await ref
                                .read(apiClientProvider)
                                .cancelBookingDetailed(b.id);
                            ref.invalidate(myBookingsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(res.message)),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                        child: const Text('Bekor qilish'),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
