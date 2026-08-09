import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/analytics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../auth/auth_provider.dart';

/// Full-screen premium paywall — FIFA / vault vibe.
class PremiumPaywallScreen extends ConsumerStatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  ConsumerState<PremiumPaywallScreen> createState() =>
      _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen> {
  bool _busy = false;

  static const _benefits = [
    ('FIFA o‘yinchi kartasi', 'Flip + karyera stats'),
    ('Bron prioritet', 'Slot band bo‘lganda birinchi'),
    ('Turnir −50% To‘p', 'Kirish narxi arzonroq'),
    ('+100 To‘p / oy', 'Har oy bonus'),
    ('Pro badge', 'Profil va reelsda'),
    ('Reklamasiz', 'Toza tajriba'),
  ];

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    Analytics.log('premium_subscribe_tap');
    try {
      await ref.read(apiClientProvider).subscribePremium(provider: 'fake');
      await ref.read(authProvider.notifier).refreshMe();
      Analytics.log('premium_subscribe_ok');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium faol · FIFA karta ochildi')),
        );
        context.pop();
      }
    } catch (e) {
      Analytics.log('premium_subscribe_fail');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isPrem = user?.isPremium == true;

    return Scaffold(
      appBar: pcAppBar(context, title: 'Premium'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2208),
                  Color(0xFF0B1510),
                  Color(0xFF1A2A1F),
                ],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDark],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPrem ? 'FAOL' : 'PLAYZON PRO',
                    style: const TextStyle(
                      color: Color(0xFF1A1000),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(Icons.workspace_premium,
                    size: 56, color: AppColors.gold),
                const SizedBox(height: 12),
                const Text(
                  'Premium',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'FIFA karta, prioritet bron va To‘p bonuslari — bitta obuna.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final b in _benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.surface2,
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.$1,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(b.$2,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (isPrem)
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Premium allaqachon faol'),
            )
          else
            ElevatedButton(
              onPressed: _busy ? null : _subscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1A1000),
                minimumSize: const Size.fromHeight(54),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'OBUNA BO‘LISH · DEMO',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Demo obuna — Click/Payme keyinroq ulanadi',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.faint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
