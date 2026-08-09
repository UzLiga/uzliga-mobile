import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
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
        const SnackBar(content: Text('Vault ochildi · To‘p qo‘shildi')),
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
      appBar: pcAppBar(context, title: 'Hamyon'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(walletProvider),
        ),
        data: (w) {
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async => ref.invalidate(walletProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _VaultHero(
                  balance: w.balance,
                  vaultProgress: _vaultCtrl,
                  successProgress: _successCtrl,
                ),
                const SizedBox(height: 22),
                const Text(
                  'Vault to‘ldirish',
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
                        selectedColor: AppColors.gold.withValues(alpha: 0.28),
                        onSelected: (_) => setState(() => _amount = p),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _amount == p
                              ? AppColors.gold
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
                      color: AppColors.gold,
                    ),
                    Expanded(
                      child: Text(
                        formatPrice(_amount),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
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
                      color: AppColors.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _vaultCtrl,
                  builder: (context, _) {
                    final opening = _vaultCtrl.value;
                    return ElevatedButton(
                      onPressed: _loading ? null : _topUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF1A1000),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color.lerp(
                                      const Color(0xFF1A1000),
                                      AppColors.primary,
                                      opening,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  opening > 0.5
                                      ? 'Vault ochilmoqda…'
                                      : 'To‘lov…',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                              ],
                            )
                          : const Text(
                              'VAULT OCHISH · TO‘LDIRISH',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Text(
                      'Tranzaksiyalar',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                      color: AppColors.surface2,
                    ),
                    child: const Text(
                      'Hali tranzaksiya yo‘q — vaultni ochib To‘p qo‘shing',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  ...[
                    for (var i = 0; i < w.items.length; i++)
                      _TxTimelineRow(
                        tx: w.items[i],
                        isLast: i == w.items.length - 1,
                      ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VaultHero extends StatelessWidget {
  const _VaultHero({
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
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A2A1F),
                Color(0xFF0B1510),
                Color(0xFF121810),
              ],
            ),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.35 + open * 0.35),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.12 + open * 0.25),
                blurRadius: 22 + open * 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TO‘P VAULT',
                      style: TextStyle(
                        color: Color(0xFF1A1000),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    open > 0.2 ? 'OCHIQ' : 'YOPIQ',
                    style: TextStyle(
                      color: open > 0.2
                          ? AppColors.primary
                          : AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Vault doors + coin
              SizedBox(
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Vault cavity
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          width: 3,
                        ),
                      ),
                    ),
                    // Coin
                    Transform.scale(
                      scale: 1 + pop * 0.12,
                      child: const _TopCoin(size: 118),
                    ),
                    // Left door
                    Positioned(
                      left: 8,
                      child: Transform(
                        alignment: Alignment.centerRight,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(-open * 1.15),
                        child: _VaultDoor(width: 70, left: true),
                      ),
                    ),
                    // Right door
                    Positioned(
                      right: 8,
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(open * 1.15),
                        child: _VaultDoor(width: 70, left: false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'To‘p balansi',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '$balance',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Surib yoki bosib — tangani aylantiring',
                style: TextStyle(color: AppColors.faint, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VaultDoor extends StatelessWidget {
  const _VaultDoor({required this.width, required this.left});
  final double width;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(
          left: left ? const Radius.circular(74) : Radius.zero,
          right: left ? Radius.zero : const Radius.circular(74),
        ),
        gradient: LinearGradient(
          begin: left ? Alignment.centerLeft : Alignment.centerRight,
          end: left ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [
            Color(0xFF2A3A30),
            Color(0xFF1A2820),
            Color(0xFF0F1812),
          ],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// Interactive 3D-ish To‘p coin — tap / drag to spin.
class _TopCoin extends StatefulWidget {
  const _TopCoin({this.size = 120});
  final double size;

  @override
  State<_TopCoin> createState() => _TopCoinState();
}

class _TopCoinState extends State<_TopCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _nudge() {
    HapticFeedback.selectionClick();
    // Burst spin via drag offset
    setState(() => _drag += math.pi * 1.2);
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
          final showBack = (angle % (math.pi * 2)) > math.pi / 2 &&
              (angle % (math.pi * 2)) < 3 * math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..rotateY(angle),
            child: Transform(
              alignment: Alignment.center,
              transform: showBack
                  ? (Matrix4.identity()..rotateY(math.pi))
                  : Matrix4.identity(),
              child: _CoinFace(size: widget.size, back: showBack),
            ),
          );
        },
      ),
    );
  }
}

class _CoinFace extends StatelessWidget {
  const _CoinFace({required this.size, required this.back});
  final double size;
  final bool back;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: back
              ? const [
                  Color(0xFFF5D76E),
                  Color(0xFFE8B923),
                  Color(0xFF8B5A00),
                ]
              : const [
                  Color(0xFFFFE08A),
                  Color(0xFFE8B923),
                  Color(0xFFB45309),
                  Color(0xFF6B3A00),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFF3C4).withValues(alpha: 0.65),
          width: 2.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner ring
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6B3A00).withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_soccer,
                size: size * 0.32,
                color: const Color(0xFF1A1000).withValues(alpha: 0.85),
              ),
              const SizedBox(height: 2),
              Text(
                back ? 'PLAYZON' : 'TO‘P',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.14,
                  color: const Color(0xFF1A1000),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxTimelineRow extends StatelessWidget {
  const _TxTimelineRow({required this.tx, required this.isLast});
  final WalletTx tx;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final credit = tx.amount >= 0;
    final color = credit ? AppColors.gold : AppColors.danger;
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
                        color: color.withValues(alpha: 0.45),
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
                color: AppColors.surface2,
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                ),
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
                    '${credit ? '+' : ''}${tx.amount}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
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
