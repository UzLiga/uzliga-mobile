import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/pitch_atmosphere.dart';
import '../../shared/widgets/widgets.dart';

final walletProvider = FutureProvider.autoDispose<WalletInfo>((ref) {
  return ref.watch(apiClientProvider).getWallet();
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with TickerProviderStateMixin {
  bool _loading = false;
  int _amount = 50000;
  late final AnimationController _vaultCtrl;
  late final AnimationController _successCtrl;

  static const _presets = [10000, 25000, 50000, 100000];

  @override
  void initState() {
    super.initState();
    _vaultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _vaultCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    if (_amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal 1000 UZS')),
      );
      return;
    }
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    await _vaultCtrl.forward(from: 0);
    try {
      final res = await ref.read(apiClientProvider).topUp(amount: _amount);
      final paymentId = (res['payment_id'] as num?)?.toInt();
      if (paymentId != null) {
        await ref.read(apiClientProvider).completePayment(paymentId);
      }
      ref.invalidate(walletProvider);
      if (!mounted) return;
      await _successCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To‘pcha qo‘shildi')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        await _vaultCtrl.reverse();
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(walletProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: pcAppBar(context, title: 'Hamyon'),
      body: PitchAtmosphere(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(walletProvider),
          ),
          data: (w) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(walletProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _TopchaHero(
                    balance: w.balance,
                    vaultProgress: _vaultCtrl,
                    successProgress: _successCtrl,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'To‘ldirish',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Demo to‘lov — Click/Payme keyinroq ulanadi',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _presets)
                        ChoiceChip(
                          label: Text(formatPrice(p)),
                          selected: _amount == p,
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.28),
                          onSelected: (_) => setState(() => _amount = p),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _amount == p
                                ? AppColors.primarySoft
                                : AppColors.ink,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _loading
                            ? null
                            : () => setState(
                                  () => _amount =
                                      (_amount - 5000).clamp(1000, 1000000),
                                ),
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppColors.primarySoft,
                      ),
                      Expanded(
                        child: Text(
                          formatPrice(_amount),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primarySoft,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loading
                            ? null
                            : () => setState(
                                  () => _amount =
                                      (_amount + 5000).clamp(1000, 1000000),
                                ),
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.primarySoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _topUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF052E12),
                      minimumSize: const Size.fromHeight(52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFF052E12),
                            ),
                          )
                        : const Text(
                            'To‘pcha qo‘shish',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Text(
                        'Tranzaksiyalar',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        '${w.items.length} ta',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (w.items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.edge),
                        color: AppColors.surface2.withValues(alpha: 0.6),
                      ),
                      child: const Text(
                        'Hali tranzaksiya yo‘q — to‘pcha qo‘shing',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  else
                    for (var i = 0; i < w.items.length; i++)
                      _TxTimelineRow(
                        tx: w.items[i],
                        isLast: i == w.items.length - 1,
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopchaHero extends StatelessWidget {
  const _TopchaHero({
    required this.balance,
    required this.vaultProgress,
    required this.successProgress,
  });

  final int balance;
  final Animation<double> vaultProgress;
  final Animation<double> successProgress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([vaultProgress, successProgress]),
      builder: (context, _) {
        final open = Curves.easeInOutCubic.transform(vaultProgress.value);
        final pop = Curves.easeOutBack.transform(successProgress.value);
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppColors.glassFillStrong,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35 + open * 0.25),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.glassGreen,
                    AppColors.surface.withValues(alpha: 0.55),
                    AppColors.bg.withValues(alpha: 0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14 + open * 0.2),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Text(
                          'TO‘PCHA',
                          style: TextStyle(
                            color: AppColors.primarySoft,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        open > 0.2 ? 'Yangilanmoqda' : 'Balans',
                        style: TextStyle(
                          color: open > 0.2
                              ? AppColors.primarySoft
                              : AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Transform.scale(
                    scale: 1 + pop * 0.1,
                    child: const _TopchaOrb(size: 120),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Balans · to‘pcha',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$balance',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primarySoft,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bosib yoki surib — to‘pchani aylantiring',
                    style: TextStyle(color: AppColors.faint, fontSize: 11),
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

/// Interaktiv yumaloq to‘pcha (foto emas — soft green orb).
class _TopchaOrb extends StatefulWidget {
  const _TopchaOrb({this.size = 120});
  final double size;

  @override
  State<_TopchaOrb> createState() => _TopchaOrbState();
}

class _TopchaOrbState extends State<_TopchaOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _nudge() {
    HapticFeedback.selectionClick();
    setState(() => _drag += math.pi * 1.1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _nudge,
      onHorizontalDragUpdate: (d) {
        setState(() => _drag += d.delta.dx * 0.03);
      },
      onHorizontalDragEnd: (_) => HapticFeedback.lightImpact(),
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          final angle = _spin.value * math.pi * 2 + _drag;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(angle * 0.35)
              ..rotateZ(angle * 0.08),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.4),
                  radius: 0.95,
                  colors: [
                    Color(0xFF6EE7A8),
                    Color(0xFF12B76A),
                    Color(0xFF0B7A4B),
                    Color(0xFF053D28),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft panels like a ball
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _BallPanelsPainter(
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sports_soccer_rounded,
                        size: widget.size * 0.28,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                      Text(
                        'TO‘PCHA',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: widget.size * 0.11,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BallPanelsPainter extends CustomPainter {
  _BallPanelsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(c, r * 0.72, p);
    canvas.drawCircle(c, r * 0.42, p);
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.2,
        c + Offset(math.cos(a), math.sin(a)) * r * 0.85,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BallPanelsPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TxTimelineRow extends StatelessWidget {
  const _TxTimelineRow({required this.tx, required this.isLast});
  final WalletTx tx;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final credit = tx.amount >= 0;
    final color = credit ? AppColors.primarySoft : AppColors.danger;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppColors.edge,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.surface2.withValues(alpha: 0.55),
                border: Border.all(color: AppColors.edge),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.reason,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (tx.note != null && tx.note!.isNotEmpty)
                          Text(
                            tx.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        if (tx.createdAt != null)
                          Text(
                            tx.createdAt!,
                            style: const TextStyle(
                                color: AppColors.faint, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${credit ? '+' : ''}${tx.amount} tp',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
