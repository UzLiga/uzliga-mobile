import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/player_card.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';

final teamsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).listTeams(limit: 40);
});

final teamDetailProvider =
    FutureProvider.autoDispose.family<TeamDetail, int>((ref, id) {
  return ref.watch(apiClientProvider).getTeam(id);
});

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamsProvider);

    return Scaffold(
      appBar: pcAppBar(
        context,
        title: 'Jamoalar',
        actions: [
          IconButton(
            tooltip: 'Invite kod',
            onPressed: () => context.push('/app/teams/join'),
            icon: const Icon(Icons.vpn_key_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/teams/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF052E12),
        icon: const Icon(Icons.add),
        label: const Text('Yaratish'),
      ),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(teamsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const EmptyState(title: 'Jamoa yo‘q');
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(teamsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = page.items[i];
                return InkWell(
                  onTap: () => context.push('/app/teams/${t.id}'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A2A1F), Color(0xFF0B1510)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFE8B923).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.surface2,
                          backgroundImage: t.logoUrl != null
                              ? NetworkImage(t.logoUrl!)
                              : null,
                          child: t.logoUrl == null
                              ? Text(
                                  t.name.isNotEmpty ? t.name[0] : 'J',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(
                                '${t.formatSize}v${t.formatSize} · ${t.membersCount} a’zo · ${t.wins}W ${t.draws}D ${t.losses}L',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8B923)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${t.formatSize}',
                            style: const TextStyle(
                              color: Color(0xFFE8B923),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
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

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamDetailProvider(teamId));
    final me = ref.watch(authProvider).user;

    return Scaffold(
      appBar: pcAppBar(
        context,
        title: 'Jamoa',),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(teamDetailProvider(teamId)),
        ),
        data: (team) {
          final isCaptain = me != null && me.id == team.captainId;
          final isMember = team.members.any((m) => m.user.id == me?.id);
          final need = team.formatSize;
          final ovr = team.members.isEmpty
              ? 0
              : (team.members
                          .map((m) => m.user.overall)
                          .reduce((a, b) => a + b) /
                      team.members.length)
                  .round();
          void openProfile(int id) => context.push('/app/users/$id');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Champions-style header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2A1F), Color(0xFF0B1510)],
                  ),
                  border: Border.all(
                      color: const Color(0xFFE8B923).withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8B923).withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.surface2,
                      backgroundImage: team.logoUrl != null
                          ? NetworkImage(team.logoUrl!)
                          : null,
                      child: team.logoUrl == null
                          ? Text(team.name[0],
                              style: const TextStyle(fontWeight: FontWeight.w900))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(team.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          Text(
                            '${team.formatSize}v${team.formatSize} · ${team.membersCount}/$need · ${team.wins}W',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        const Text('OVR',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFFE8B923))),
                        Text('$ovr',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE8B923))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PitchFormation(
                members: team.members,
                formatSize: team.formatSize,
                captainId: team.captainId,
                onPlayerTap: (u) => openProfile(u.id),
              ),
              const SizedBox(height: 14),
              const Text('Tarkib',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: team.members.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final m = team.members[i];
                    return PlayerCard.fromUser(
                      m.user,
                      isCaptain: m.role == 'captain',
                      onTap: () => openProfile(m.user.id),
                    );
                  },
                ),
              ),
              if (isMember && team.membersCount >= (team.formatSize >= 11 ? 8 : 5)) ...[
                const SizedBox(height: 16),
                _MatchmakingCard(teamId: team.id, teamName: team.name),
              ] else if (isMember) ...[
                const SizedBox(height: 12),
                Text(
                  'Raqib / challenge uchun ${team.formatSize} a’zo kerak (hozir ${team.membersCount})',
                  style: const TextStyle(color: AppColors.faint, fontSize: 12),
                ),
              ],
              if (isCaptain) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final list = await ref
                          .read(apiClientProvider)
                          .suggestPlayersForTeam(team.id);
                      if (!context.mounted) return;
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Yaqin tavsiyalar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                              const SizedBox(height: 10),
                              Expanded(
                                child: list.isEmpty
                                    ? const Text('Hozircha «bora olaman» yo‘q',
                                        style: TextStyle(color: AppColors.muted))
                                    : ListView.builder(
                                        itemCount: list.length,
                                        itemBuilder: (_, i) {
                                          final p = list[i];
                                          final uid =
                                              (p['id'] as num?)?.toInt();
                                          return ListTile(
                                            onTap: uid == null
                                                ? null
                                                : () {
                                                    Navigator.pop(context);
                                                    context.push(
                                                        '/app/users/$uid');
                                                  },
                                            leading: PlayerCard(
                                              name: (p['full_name'] as String? ??
                                                      '?')
                                                  .split(' ')
                                                  .first
                                                  .toUpperCase(),
                                              overall: (p['overall'] as num?)
                                                      ?.toInt() ??
                                                  65,
                                              position:
                                                  p['position'] as String?,
                                              avatarUrl:
                                                  p['avatar_url'] as String?,
                                              compact: true,
                                              showFullStatsOnTap: false,
                                            ),
                                            title: Text(
                                                p['full_name'] as String? ?? ''),
                                            subtitle: Text(
                                              '${p['distance_km'] ?? '—'} km · ${p['district'] ?? 'hudud'}',
                                              style: const TextStyle(
                                                  color: AppColors.muted,
                                                  fontSize: 12),
                                            ),
                                            trailing: const Icon(
                                                Icons.chevron_right,
                                                color: AppColors.faint),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.person_search),
                  label: const Text('Yaqin o‘yinchilar (8–9)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final ops = await ref
                          .read(apiClientProvider)
                          .suggestOpponents(team.id);
                      if (!context.mounted) return;
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: ListView(
                            children: [
                              const Text('Raqib jamoalar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                              const SizedBox(height: 10),
                              for (final o in ops)
                                ListTile(
                                  title: Text(o['name'] as String? ?? ''),
                                  subtitle: Text(
                                    '${o['members_count']}/${o['format_size']} · ${o['suggested_stadium_name'] ?? 'stadion'}',
                                  ),
                                  trailing: TextButton(
                                    onPressed: () async {
                                      final date = DateTime.now()
                                          .add(const Duration(days: 2));
                                      await ref
                                          .read(apiClientProvider)
                                          .sendTeamChallenge({
                                        'from_team_id': team.id,
                                        'to_team_id': o['id'],
                                        'proposed_date':
                                            date.toIso8601String().split('T').first,
                                        'proposed_time': '20:00',
                                        'stadium_id':
                                            o['suggested_stadium_id'],
                                      });
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Taklif yuborildi')),
                                        );
                                      }
                                    },
                                    child: const Text('Taklif'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('To‘liq jamoaga o‘yin taklifi'),
                ),
              ],
              if (isCaptain && team.inviteCode != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.edge),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invite kod',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              team.inviteCode!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: team.inviteCode!),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Kod nusxalandi')),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (!isMember) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).joinTeam(team.id);
                      ref.invalidate(teamDetailProvider(teamId));
                      ref.invalidate(teamsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Jamoaga qo‘shildingiz')),
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
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class TeamJoinScreen extends ConsumerStatefulWidget {
  const TeamJoinScreen({super.key, this.code});

  final String? code;

  @override
  ConsumerState<TeamJoinScreen> createState() => _TeamJoinScreenState();
}

class _TeamJoinScreenState extends ConsumerState<TeamJoinScreen> {
  late final TextEditingController _codeCtrl;
  TeamInvitePreview? _preview;
  String? _error;
  bool _loading = false;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.code?.toUpperCase() ?? '');
    if ((widget.code ?? '').trim().length >= 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) return;
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await ref.read(apiClientProvider).getTeamInvitePreview(code);
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = 'Invite topilmadi');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final code = (_preview?.inviteCode ?? _codeCtrl.text).trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _accepting = true);
    try {
      final team = await ref.read(apiClientProvider).acceptTeamInvite(code);
      ref.invalidate(teamsProvider);
      if (!mounted) return;
      context.push('/app/teams/${team.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pcAppBar(
        context,
        title: 'Jamoa invite',),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Invite kod',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _lookup(),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loading ? null : _lookup,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tekshirish'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.surface2,
                    backgroundImage: _preview!.logoUrl != null
                        ? NetworkImage(_preview!.logoUrl!)
                        : null,
                    child: _preview!.logoUrl == null
                        ? Text(
                            _preview!.name.isNotEmpty ? _preview!.name[0] : 'J',
                            style: const TextStyle(fontSize: 28),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _preview!.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_preview!.membersCount} a’zo'
                    '${_preview!.captainName != null ? ' · Sardor: ${_preview!.captainName}' : ''}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _preview!.inviteCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _accepting ? null : _accept,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: _accepting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Jamoaga qo‘shilish'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _busy = false;
  int _format = 7;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final team = await ref.read(apiClientProvider).createTeam(
            name: _name.text.trim(),
            description: _desc.text.trim(),
            formatSize: _format,
          );
      ref.invalidate(teamsProvider);
      if (!mounted) return;
      context.push('/app/teams/${team.id}');
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
      appBar: pcAppBar(
        context,
        title: 'Jamoa yaratish',),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Jamoa nomi'),
            ),
            const SizedBox(height: 12),
            const Text('Maydon formati',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in [5, 7, 11])
                  ChoiceChip(
                    label: Text(
                        f == 11 ? '11 (katta)' : f == 5 ? '5 (mini)' : '7 (mini)'),
                    selected: _format == f,
                    onSelected: (_) => setState(() => _format = f),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _format == 11
                  ? 'Katta polya — 11 o‘yinchi'
                  : 'Mini polya — odatda 5–7',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Tavsif'),
              maxLines: 3,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Yaratish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchmakingCard extends ConsumerStatefulWidget {
  const _MatchmakingCard({required this.teamId, required this.teamName});
  final int teamId;
  final String teamName;

  @override
  ConsumerState<_MatchmakingCard> createState() => _MatchmakingCardState();
}

class _MatchmakingCardState extends ConsumerState<_MatchmakingCard> {
  bool _busy = false;
  String? _status;
  String? _message;

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final res =
          await ref.read(apiClientProvider).matchmakingFind(widget.teamId);
      if (!mounted) return;
      setState(() {
        _status = res['status'] as String?;
        _message = res['message'] as String? ??
            (res['status'] == 'waiting'
                ? 'Raqib qidirilmoqda…'
                : 'Raqib topildi');
      });
      if (_status == 'matched' && res['game_id'] != null) {
        final stadium = res['stadium'] as Map?;
        final away = res['away_team'] as Map?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Match! ${away?['name'] ?? 'Raqib'} · '
              '${stadium?['name'] ?? 'Stadion'} · '
              '${res['date']} ${res['start_time']}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    try {
      await ref.read(apiClientProvider).matchmakingCancel(widget.teamId);
      if (mounted) {
        setState(() {
          _status = 'cancelled';
          _message = 'Navbat bekor qilindi';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Raqib izlash',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            '5v5 · darajangizga mos bo‘sh jamoa topiladi va maydonga birlashtiriladi',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                color: _status == 'matched'
                    ? AppColors.primary
                    : AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _find,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_status == 'waiting' ? 'Qidirish…' : 'Raqib izlash'),
                ),
              ),
              if (_status == 'waiting') ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('Bekor'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
