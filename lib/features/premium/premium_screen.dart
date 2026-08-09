import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/analytics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../auth/auth_provider.dart';

/// Premium paywall — karta + chek → admin tasdiqlashi.
class PremiumPaywallScreen extends ConsumerStatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  ConsumerState<PremiumPaywallScreen> createState() =>
      _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen> {
  bool _busy = false;
  Map<String, dynamic>? _status;
  XFile? _proof;
  int? _paymentId;

  static const _benefits = [
    ('FIFA o‘yinchi kartasi', 'Flip + karyera stats'),
    ('Bron prioritet', 'Slot band bo‘lganda birinchi'),
    ('Turnir −50% To‘p', 'Kirish narxi arzonroq'),
    ('+100 To‘p / oy', 'Har oy bonus'),
    ('Pro badge', 'Profil va reelsda'),
    ('Reklamasiz', 'Toza tajriba'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(apiClientProvider).premiumStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _paymentId = s['pending_payment_id'] as int?;
      });
    } catch (_) {}
  }

  String? get _card {
    final n = (_status?['payout_card_number'] as String?)?.replaceAll(' ', '');
    if (n == null || n.isEmpty) return null;
    final buf = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(n[i]);
    }
    return buf.toString();
  }

  Future<void> _copyCard() async {
    final raw = (_status?['payout_card_number'] as String?) ?? '';
    if (raw.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: raw.replaceAll(' ', '')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Karta raqami nusxalandi')),
    );
  }

  Future<void> _startPayment() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    Analytics.log('premium_subscribe_tap');
    try {
      final res =
          await ref.read(apiClientProvider).subscribePremium(provider: 'card');
      setState(() {
        _paymentId = res['payment_id'] as int?;
        _status = {...?_status, ...res};
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickProof() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (f == null || !mounted) return;
    setState(() => _proof = f);
  }

  Future<void> _submitProof() async {
    if (_paymentId == null) {
      await _startPayment();
    }
    final id = _paymentId;
    if (id == null || _proof == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval chek rasmini tanlang')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiClientProvider).uploadPremiumPaymentProof(
            paymentId: id,
            filePath: _proof!.path,
            fileName: _proof!.name,
          );
      Analytics.log('premium_proof_ok');
      await _load();
      if (!mounted) return;
      final auth = res['payment_proof_authenticity'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth != null
                ? 'Chek yuborildi · haqiqiylik $auth%. Admin tekshiradi.'
                : 'Chek yuborildi · admin tekshiruvi kutilmoqda.',
          ),
        ),
      );
    } catch (e) {
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
    final price = (_status?['price_monthly'] as num?)?.toInt() ?? 39000;
    final holder = _status?['payout_card_holder'] as String?;
    final pendingAuth = _status?['pending_authenticity'] as int?;
    final pendingProof = _status?['pending_proof_status'] as String?;

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
            ),
            child: Column(
              children: [
                Text(
                  isPrem ? 'FAOL' : 'PLAYZON PRO',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
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
                Text(
                  '${formatPrice(price)} / oy',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          if (!isPrem) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
                border: Border.all(color: const Color(0xFF46ED13), width: 1.3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shu kartaga o‘tkazing',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF46ED13),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_card != null) ...[
                    SelectableText(
                      _card!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (holder != null && holder.isNotEmpty)
                      Text(holder,
                          style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _copyCard,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Raqamni nusxalash'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF46ED13),
                          foregroundColor: const Color(0xFF06210C),
                        ),
                      ),
                    ),
                  ] else
                    const Text(
                      'Admin hali karta kiritmagan. Keyinroq urinib ko‘ring.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Summa: ${formatPrice(price)} — chek/skrinshot yuklang, admin foiz bilan ko‘radi.',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _busy ? null : _pickProof,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _proof != null ? AppColors.gold : AppColors.edge,
                  ),
                ),
                child: Row(
                  children: [
                    if (_proof != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_proof!.path),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      const Icon(Icons.receipt_long_rounded,
                          color: AppColors.muted, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _proof == null
                            ? 'To‘lov chekini yuklash'
                            : 'Chek tanlandi',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pendingProof != null) ...[
              const SizedBox(height: 10),
              Text(
                pendingAuth != null
                    ? 'Tekshiruvda · haqiqiylik $pendingAuth%'
                    : 'Tekshiruvda — admin javobini kuting',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _submitProof,
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
                      'Chekni yuborish',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ] else
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Premium allaqachon faol'),
            ),
        ],
      ),
    );
  }
}
