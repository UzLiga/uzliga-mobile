import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
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

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _loading = false;
  final _amountCtrl = TextEditingController(text: '50000');

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal 1000 UZS')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).topUp(amount: amount);
      final paymentId = (res['payment_id'] as num?)?.toInt();
      if (paymentId != null) {
        await ref.read(apiClientProvider).completePayment(paymentId);
      }
      ref.invalidate(walletProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hamyon to‘ldirildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hamyon')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(walletProvider),
        ),
        data: (w) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.surface2,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('To‘p balansi', style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Text(
                      '${w.balance}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('To‘ldirish', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Summa (UZS)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loading ? null : _topUp,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('To‘ldirish (demo)'),
              ),
              const SizedBox(height: 24),
              const Text('Tranzaksiyalar', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (w.items.isEmpty)
                const Text('Hali tranzaksiya yo‘q', style: TextStyle(color: AppColors.muted))
              else
                ...w.items.map(
                  (tx) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx.reason, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(tx.note ?? tx.createdAt ?? ''),
                    trailing: Text(
                      '${tx.amount > 0 ? '+' : ''}${tx.amount}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: tx.amount >= 0 ? AppColors.primary : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
