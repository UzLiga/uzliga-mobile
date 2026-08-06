import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

final teamsProvider = FutureProvider.autoDispose((ref) {
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
      appBar: AppBar(title: const Text('Jamoalar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/teams/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF052E12),
        icon: const Icon(Icons.add),
        label: const Text('Yaratish'),
      ),
      body: async.when(
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
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/app/teams/${t.id}'),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surface2,
                      backgroundImage:
                          t.logoUrl != null ? NetworkImage(t.logoUrl!) : null,
                      child: t.logoUrl == null
                          ? Text(t.name.isNotEmpty ? t.name[0] : 'J')
                          : null,
                    ),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${t.membersCount} a’zo · ${t.wins}W ${t.draws}D ${t.losses}L',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Jamoa')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(teamDetailProvider(teamId)),
        ),
        data: (team) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(team.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              if (team.description != null && team.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(team.description!, style: const TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 12),
              Text(
                '${team.membersCount} a’zo · ${team.wins}W ${team.draws}D ${team.losses}L',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              const Text('A’zolar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              ...team.members.map(
                (m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surface2,
                    child: Text(
                      m.user.fullName.isNotEmpty ? m.user.fullName[0] : '?',
                    ),
                  ),
                  title: Text(m.user.fullName),
                  subtitle: Text(m.role == 'captain' ? 'Kapitan' : 'O‘yinchi'),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ref.read(apiClientProvider).joinTeam(team.id);
                    ref.invalidate(teamDetailProvider(teamId));
                    ref.invalidate(teamsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Jamoaga qo‘shildingiz')),
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
          );
        },
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
          );
      ref.invalidate(teamsProvider);
      if (!mounted) return;
      context.go('/app/teams/${team.id}');
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
      appBar: AppBar(title: const Text('Jamoa yaratish')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Jamoa nomi'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Tavsif'),
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
      ),
    );
  }
}
