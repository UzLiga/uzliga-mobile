import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

final battlesProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).listBattles();
});

class BattlesScreen extends ConsumerWidget {
  const BattlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(battlesProvider);
    return Scaffold(
      appBar: pcAppBar(context, title: 'Random Battle'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(battlesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'Battle yo‘q',
              subtitle: 'Tez orada shanba / ixtiyoriy battle ochiladi',
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(battlesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.12),
                          AppColors.surface2,
                        ],
                      ),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      'Ixtiyoriy battle — 2–3 kun oldin ochiladi.\n'
                      'Shanba 20:00 majburiy Random — qo‘shilmaganlarga To‘p jarima.',
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                  );
                }
                return _BattlePoster(
                  battle: list[i - 1],
                  onJoin: () async {
                    try {
                      await ref.read(apiClientProvider).joinBattle(
                            (list[i - 1]['id'] as num).toInt(),
                          );
                      ref.invalidate(battlesProvider);
                      if (context.mounted) {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Battle’ga qo‘shildingiz')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Fight-poster style battle card + live countdown.
class _BattlePoster extends StatefulWidget {
  const _BattlePoster({required this.battle, required this.onJoin});

  final Map<String, dynamic> battle;
  final VoidCallback onJoin;

  @override
  State<_BattlePoster> createState() => _BattlePosterState();
}

class _BattlePosterState extends State<_BattlePoster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  Timer? _tick;
  Duration _left = Duration.zero;

  Map<String, dynamic> get b => widget.battle;

  DateTime? get _kickoff {
    final dateStr = '${b['date'] ?? ''}';
    final timeStr = '${b['start_time'] ?? '20:00'}';
    try {
      final d = DateTime.parse(dateStr);
      final parts = timeStr.split(':');
      final h = int.tryParse(parts[0]) ?? 20;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return DateTime(d.year, d.month, d.day, h, m);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _recompute();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  void _recompute() {
    final k = _kickoff;
    if (k == null) return;
    final left = k.difference(DateTime.now());
    if (mounted) setState(() => _left = left.isNegative ? Duration.zero : left);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _glow.dispose();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final mandatory = b['is_mandatory'] == true;
    final title = b['title'] as String? ?? 'Battle';
    final stadium = b['stadium_name'] as String? ?? 'Stadion';
    final format = b['format_size'] ?? 7;
    final players = (b['players_count'] as num?)?.toInt() ?? 0;
    final max = (b['max_players'] as num?)?.toInt() ?? 14;
    final penalty = (b['penalty_top'] as num?)?.toInt() ?? 0;
    final fill = max == 0 ? 0.0 : (players / max).clamp(0.0, 1.0);
    final days = _left.inDays;
    final hours = _left.inHours % 24;
    final mins = _left.inMinutes % 60;
    final secs = _left.inSeconds % 60;
    final started = _kickoff != null && DateTime.now().isAfter(_kickoff!);

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final pulse = mandatory ? _glow.value : 0.35;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (mandatory ? AppColors.danger : AppColors.gold)
                    .withValues(alpha: 0.12 + pulse * 0.22),
                blurRadius: 18 + pulse * 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: mandatory
                      ? const [
                          Color(0xFF4A1515),
                          Color(0xFF1A0A0A),
                          Color(0xFF0B1510),
                        ]
                      : const [
                          Color(0xFF1A2A1F),
                          Color(0xFF0B1510),
                          Color(0xFF121810),
                        ],
                ),
                border: Border.all(
                  color: mandatory
                      ? AppColors.danger.withValues(alpha: 0.55)
                      : AppColors.gold.withValues(alpha: 0.5),
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header strip
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: mandatory
                            ? [
                                AppColors.danger.withValues(alpha: 0.35),
                                Colors.transparent,
                              ]
                            : [
                                AppColors.gold.withValues(alpha: 0.28),
                                Colors.transparent,
                              ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: mandatory
                                ? AppColors.danger
                                : AppColors.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            mandatory ? 'SHANBA · MAJBURIY' : 'IXTIYORIY',
                            style: TextStyle(
                              color: mandatory
                                  ? Colors.white
                                  : const Color(0xFF1A1000),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${format}v$format',
                          style: TextStyle(
                            color: mandatory
                                ? Colors.white70
                                : AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatDateShort('${b['date']}')} · ${b['start_time']} · $stadium',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  // VS row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SidePlate(
                            label: 'SIZ',
                            sub: 'Join',
                            accent: AppColors.gold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Text(
                                'VS',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: mandatory
                                      ? AppColors.danger
                                      : AppColors.gold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: (mandatory
                                              ? AppColors.danger
                                              : AppColors.gold)
                                          .withValues(alpha: 0.55),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$players/$max',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _SidePlate(
                            label: 'RANDOM',
                            sub: 'Pool',
                            accent: mandatory
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Countdown
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: started
                          ? const Text(
                              'Kickoff boshlandi',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _CountCell(label: 'KUN', value: _pad(days)),
                                _CountCell(label: 'SOAT', value: _pad(hours)),
                                _CountCell(label: 'DAQ', value: _pad(mins)),
                                _CountCell(label: 'SON', value: _pad(secs)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: fill,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        color: mandatory ? AppColors.danger : AppColors.gold,
                      ),
                    ),
                  ),
                  if (mandatory && penalty > 0) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Qo‘shilmasa −$penalty To‘p jarima',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ElevatedButton(
                      onPressed: widget.onJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            mandatory ? AppColors.danger : AppColors.gold,
                        foregroundColor: mandatory
                            ? Colors.white
                            : const Color(0xFF1A1000),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'JOIN · STAMP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
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

class _SidePlate extends StatelessWidget {
  const _SidePlate({
    required this.label,
    required this.sub,
    required this.accent,
  });

  final String label;
  final String sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black26,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(Icons.sports_soccer, color: accent, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: accent,
              letterSpacing: 1,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CountCell extends StatelessWidget {
  const _CountCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.gold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
