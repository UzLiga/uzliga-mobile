import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

final gamesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(apiClientProvider).listGames(status: 'open', limit: 40);
});

final gameDetailProvider =
    FutureProvider.autoDispose.family<GameDetail, int>((ref, id) {
  return ref.watch(apiClientProvider).getGame(id);
});

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gamesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/games/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF052E12),
        icon: const Icon(Icons.add),
        label: const Text('Yaratish'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'O‘yinlar',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(gamesProvider),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return EmptyState(
                      title: 'Ochiq o‘yin yo‘q',
                      subtitle: 'Birinchi bo‘lib o‘yin yarating',
                      action: ElevatedButton(
                        onPressed: () => context.push('/app/games/create'),
                        child: const Text('O‘yin yaratish'),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(gamesProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: page.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final g = page.items[i];
                        return Card(
                          child: ListTile(
                            onTap: () => context.push('/app/games/${g.id}'),
                            title: Text(
                              g.stadium.name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${formatDateShort(g.date)} · ${g.startTime} · ${g.format}\n'
                              '${g.playersCount}/${g.maxPlayers} o‘yinchi'
                              '${g.pricePerPlayer != null ? ' · ${formatPrice(g.pricePerPlayer!)}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
                          ),
                        );
                      },
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

class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gameDetailProvider(gameId));

    return Scaffold(
      appBar: AppBar(title: const Text('O‘yin')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(gameDetailProvider(gameId)),
        ),
        data: (game) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(game.stadium.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                '${formatDateShort(game.date)} · ${game.startTime} · ${game.format}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                'Yaratuvchi: ${game.creator.fullName}',
                style: const TextStyle(color: AppColors.muted),
              ),
              if (game.comment != null && game.comment!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(game.comment!),
              ],
              const SizedBox(height: 20),
              Text(
                'O‘yinchilar (${game.players.length}/${game.maxPlayers})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...game.players.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surface2,
                    child: Text(p.fullName.isNotEmpty ? p.fullName[0] : '?'),
                  ),
                  title: Text(p.fullName),
                  subtitle: Text(p.position ?? 'O‘yinchi'),
                ),
              ),
              const SizedBox(height: 16),
              if (game.isOpen)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).joinGame(game.id);
                      ref.invalidate(gameDetailProvider(gameId));
                      ref.invalidate(gamesProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('O‘yinga qo‘shildingiz')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: const Text('Qo‘shilish'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await ref.read(apiClientProvider).leaveGame(game.id);
                    ref.invalidate(gameDetailProvider(gameId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('O‘yindan chiqdingiz')),
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
          );
        },
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
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  String _format = '7x7';
  int _maxPlayers = 14;
  bool _busy = false;
  List<Stadium> _stadiums = const [];

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
      }
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stadium == null) return;
    setState(() => _busy = true);
    try {
      final date = DateFormat('yyyy-MM-dd').format(_date);
      final start =
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      final game = await ref.read(apiClientProvider).createGame({
        'stadium_id': _stadium!.id,
        'date': date,
        'start_time': start,
        'format': _format,
        'max_players': _maxPlayers,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      ref.invalidate(gamesProvider);
      if (!mounted) return;
      context.go('/app/games/${game.id}');
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
      appBar: AppBar(title: const Text('O‘yin yaratish')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Stadium>(
            initialValue: _stadium,
            decoration: const InputDecoration(labelText: 'Stadion'),
            items: _stadiums
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _stadium = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sana'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 60)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vaqt'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _format,
            decoration: const InputDecoration(labelText: 'Format'),
            items: const [
              DropdownMenuItem(value: '5x5', child: Text('5x5')),
              DropdownMenuItem(value: '6x6', child: Text('6x6')),
              DropdownMenuItem(value: '7x7', child: Text('7x7')),
              DropdownMenuItem(value: '11x11', child: Text('11x11')),
            ],
            onChanged: (v) => setState(() => _format = v ?? '7x7'),
          ),
          const SizedBox(height: 12),
          TextFormField(
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
