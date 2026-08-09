import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/player_card.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';

enum _GamesTab { open, mine, today }

final gamesOpenProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).listGames(status: 'open', limit: 50);
});

final gamesMineProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).myGames(limit: 50);
});

final gameDetailProvider =
    FutureProvider.autoDispose.family<GameDetail, int>((ref, id) {
  return ref.watch(apiClientProvider).getGame(id);
});

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  _GamesTab _tab = _GamesTab.open;
  String? _format;

  @override
  Widget build(BuildContext context) {
    final async = _tab == _GamesTab.mine
        ? ref.watch(gamesMineProvider)
        : ref.watch(gamesOpenProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/games/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF003D26),
        icon: const Icon(Icons.add),
        label: const Text('Yaratish'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'O‘yinlar',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  _SegChip(
                    label: 'Ochiq',
                    selected: _tab == _GamesTab.open,
                    onTap: () => setState(() => _tab = _GamesTab.open),
                  ),
                  const SizedBox(width: 8),
                  _SegChip(
                    label: 'Mening',
                    selected: _tab == _GamesTab.mine,
                    onTap: () => setState(() => _tab = _GamesTab.mine),
                  ),
                  const SizedBox(width: 8),
                  _SegChip(
                    label: 'Bugun',
                    selected: _tab == _GamesTab.today,
                    onTap: () => setState(() => _tab = _GamesTab.today),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in [null, '5x5', '7x7', '11x11'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f ?? 'Hammasi'),
                        selected: _format == f,
                        onSelected: (_) => setState(() => _format = f),
                        selectedColor:
                            const Color(0xFFE8B923).withValues(alpha: 0.25),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.stadium_outlined, size: 16),
                    label: const Text('Maydon bron'),
                    onPressed: () => context.push('/app/stadiums'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () {
                    ref.invalidate(gamesOpenProvider);
                    ref.invalidate(gamesMineProvider);
                  },
                ),
                data: (page) {
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  var items = page.items.toList();
                  if (_tab == _GamesTab.today) {
                    items = items.where((g) => g.date.startsWith(today)).toList();
                  }
                  if (_format != null) {
                    items = items.where((g) => g.format == _format).toList();
                  }
                  if (items.isEmpty) {
                    return EmptyState(
                      title: _tab == _GamesTab.mine
                          ? 'Sizda o‘yin yo‘q'
                          : 'Ochiq o‘yin yo‘q',
                      subtitle: 'Birinchi bo‘lib o‘yin yarating yoki maydon bron qiling',
                      action: ElevatedButton(
                        onPressed: () => context.push('/app/games/create'),
                        child: const Text('O‘yin yaratish'),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(gamesOpenProvider);
                      ref.invalidate(gamesMineProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _GameCard(game: items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFE8B923), Color(0xFFB45309)],
                )
              : null,
          color: selected ? null : AppColors.surface2,
          border: Border.all(
            color: selected
                ? const Color(0xFFE8B923)
                : AppColors.edge,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? const Color(0xFF1A1000) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final fill = game.maxPlayers == 0
        ? 0.0
        : (game.playersCount / game.maxPlayers).clamp(0.0, 1.0);
    final spots = (game.maxPlayers - game.playersCount).clamp(0, 99);
    return InkWell(
      onTap: () => context.push('/app/games/${game.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF163528), Color(0xFF0B1510)],
          ),
          border: Border.all(
            color: const Color(0xFFE8B923).withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PcNetworkImage(url: game.stadium.imageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xEE0B1510)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    right: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.stadium.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8B923)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            game.format,
                            style: const TextStyle(
                              color: Color(0xFFE8B923),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatDateShort(game.date)} · ${game.startTime}'
                    '${game.pricePerPlayer != null ? ' · ${formatPrice(game.pricePerPlayer!)}/odam' : ''}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: fill,
                      minHeight: 7,
                      backgroundColor: Colors.white12,
                      color: spots == 0
                          ? AppColors.danger
                          : const Color(0xFFE8B923),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${game.playersCount}/${game.maxPlayers} o‘yinchi',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        spots == 0 ? 'To‘ldi' : '$spots joy bo‘sh',
                        style: TextStyle(
                          color: spots == 0
                              ? AppColors.danger
                              : AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipCtrl.isAnimating) return;
    HapticFeedback.selectionClick();
    if (_flipCtrl.value < 0.5) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 180) return;
    _flip();
  }

  int _formatSize(String format) {
    if (format.startsWith('5')) return 5;
    if (format.startsWith('11')) return 11;
    return 7;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gameDetailProvider(widget.gameId));
    final me = ref.watch(authProvider).user;

    return Scaffold(
      appBar: pcAppBar(context, title: 'O‘yin'),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(gameDetailProvider(widget.gameId)),
        ),
        data: (game) {
          final isMember =
              me != null && game.players.any((p) => p.id == me.id);
          final full = game.playersCount >= game.maxPlayers;
          final fill = game.maxPlayers == 0
              ? 0.0
              : (game.playersCount / game.maxPlayers).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedBuilder(
                animation: _flipCtrl,
                builder: (context, _) {
                  final t =
                      Curves.easeInOutCubic.transform(_flipCtrl.value);
                  final angle = t * math.pi;
                  final showBack = angle > math.pi / 2;
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: _flip,
                        onHorizontalDragEnd: _onDragEnd,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(angle),
                          child: showBack
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateY(math.pi),
                                  child: PitchFormation.fromUsers(
                                    players: game.players,
                                    formatSize: _formatSize(game.format),
                                    captainId: game.creator.id,
                                    onPlayerTap: (u) =>
                                        context.push('/app/users/${u.id}'),
                                  ),
                                )
                              : _GameInfoFront(game: game, fill: fill),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        showBack
                            ? 'Surish / bosish — o‘yin ma’lumoti'
                            : 'Surish / bosish — tarkib (pitch)',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fill,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'O‘yinchilar (${game.players.length}/${game.maxPlayers})',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in game.players)
                    GestureDetector(
                      onTap: () => context.push('/app/users/${p.id}'),
                      child: SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.surface2,
                              backgroundImage: p.avatarUrl != null
                                  ? NetworkImage(p.avatarUrl!)
                                  : null,
                              child: p.avatarUrl == null
                                  ? Text(p.fullName.isNotEmpty
                                      ? p.fullName[0]
                                      : '?')
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (game.isOpen && !isMember)
                ElevatedButton(
                  onPressed: full
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(apiClientProvider)
                                .joinGame(game.id);
                            ref.invalidate(
                                gameDetailProvider(widget.gameId));
                            ref.invalidate(gamesOpenProvider);
                            ref.invalidate(gamesMineProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('O‘yinga qo‘shildingiz')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')));
                            }
                          }
                        },
                  child: Text(full ? 'Joy yo‘q' : 'Qo‘shilish'),
                ),
              if (isMember) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).leaveGame(game.id);
                      ref.invalidate(gameDetailProvider(widget.gameId));
                      ref.invalidate(gamesOpenProvider);
                      ref.invalidate(gamesMineProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('O‘yindan chiqdingiz')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: const Text('Chiqish'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/app/stadiums/${game.stadium.id}'),
                icon: const Icon(Icons.stadium_outlined),
                label: const Text('Maydonni bron qilish'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GameInfoFront extends StatelessWidget {
  const _GameInfoFront({required this.game, required this.fill});

  final GameDetail game;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PcNetworkImage(url: game.stadium.imageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xEE0B1510)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      game.format.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF1A1000),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  right: 14,
                  child: Text(
                    game.stadium.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatDateShort(game.date)} · ${game.startTime}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Yaratuvchi: ${game.creator.fullName}',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                if (game.comment != null && game.comment!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(game.comment!),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.groups,
                        size: 16,
                        color: AppColors.gold.withValues(alpha: 0.9)),
                    const SizedBox(width: 6),
                    Text(
                      '${game.playersCount}/${game.maxPlayers} · ${(fill * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Tarkib →',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateGameScreen extends ConsumerStatefulWidget {
  const CreateGameScreen({super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  final _comment = TextEditingController();
  Stadium? _stadium;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _slot;
  String _format = '7x7';
  int _maxPlayers = 14;
  bool _busy = false;
  bool _loadingSlots = false;
  List<Stadium> _stadiums = const [];
  List<AvailabilitySlot> _slots = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final page = await ref.read(apiClientProvider).listStadiums(limit: 50);
      if (mounted) {
        setState(() {
          _stadiums = page.items;
          if (_stadiums.isNotEmpty) _stadium = _stadiums.first;
        });
        await _loadSlots();
      }
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _loadSlots() async {
    if (_stadium == null) return;
    setState(() {
      _loadingSlots = true;
      _slot = null;
    });
    try {
      final a = await ref
          .read(apiClientProvider)
          .stadiumAvailability(_stadium!.id, _dateStr);
      if (mounted) {
        setState(() {
          _slots = a.slots.where((s) => s.available).toList();
          _loadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _submit() async {
    if (_stadium == null) return;
    if (_slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bo‘sh vaqt tanlang yoki maydon bron qiling')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final game = await ref.read(apiClientProvider).createGame({
        'stadium_id': _stadium!.id,
        'date': _dateStr,
        'start_time': _slot,
        'format': _format,
        'max_players': _maxPlayers,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      ref.invalidate(gamesOpenProvider);
      ref.invalidate(gamesMineProvider);
      if (!mounted) return;
      context.push('/app/games/${game.id}');
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
    return Scaffold(
      appBar: pcAppBar(context, title: 'O‘yin yaratish'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Stadium>(
            initialValue: _stadium,
            decoration: const InputDecoration(labelText: 'Stadion'),
            items: _stadiums
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (v) async {
              setState(() => _stadium = v);
              await _loadSlots();
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sana'),
            subtitle: Text(_dateStr),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 60)),
              );
              if (d != null) {
                setState(() => _date = d);
                await _loadSlots();
              }
            },
          ),
          const Text('Bo‘sh slot', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_loadingSlots)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LoadingView(),
            )
          else if (_slots.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bu kunda bo‘sh slot yo‘q',
                    style: TextStyle(color: AppColors.muted)),
                TextButton(
                  onPressed: _stadium == null
                      ? null
                      : () => context.push('/app/stadiums/${_stadium!.id}'),
                  child: const Text('Maydon bron sahifasi →'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.map((s) {
                final selected = _slot == s.startTime;
                return ChoiceChip(
                  label: Text(s.startTime),
                  selected: selected,
                  onSelected: (_) => setState(() => _slot = s.startTime),
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _format,
            decoration: const InputDecoration(labelText: 'Format'),
            items: const [
              DropdownMenuItem(value: '5x5', child: Text('5x5')),
              DropdownMenuItem(value: '6x6', child: Text('6x6')),
              DropdownMenuItem(value: '7x7', child: Text('7x7')),
              DropdownMenuItem(value: '11x11', child: Text('11x11')),
            ],
            onChanged: (v) {
              setState(() {
                _format = v ?? '7x7';
                _maxPlayers = _format == '5x5'
                    ? 10
                    : _format == '11x11'
                        ? 22
                        : 14;
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(_maxPlayers),
            initialValue: '$_maxPlayers',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Max o‘yinchilar'),
            onChanged: (v) => _maxPlayers = int.tryParse(v) ?? 14,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Yaratish'),
          ),
        ],
      ),
    );
  }
}
