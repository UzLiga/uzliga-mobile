import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

final stadiumsSearchProvider = NotifierProvider<StadiumsSearchNotifier, String>(
  StadiumsSearchNotifier.new,
);

class StadiumsSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final stadiumsProvider = FutureProvider.autoDispose((ref) {
  final q = ref.watch(stadiumsSearchProvider);
  return ref.watch(apiClientProvider).listStadiums(search: q, limit: 40, sort: '-rating');
});

final stadiumDetailProvider =
    FutureProvider.autoDispose.family<Stadium, int>((ref, id) {
  return ref.watch(apiClientProvider).getStadium(id);
});

class StadiumsScreen extends ConsumerWidget {
  const StadiumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stadiumsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stadionlar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) =>
                  ref.read(stadiumsSearchProvider.notifier).setQuery(v),
              decoration: const InputDecoration(
                hintText: 'Qidirish...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(stadiumsProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyState(title: 'Stadion topilmadi');
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(stadiumsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = page.items[i];
                      return InkWell(
                        onTap: () => context.push('/app/stadiums/${s.id}'),
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 96,
                                height: 96,
                                child: PcNetworkImage(url: s.imageUrl),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${s.district} · ${s.size}',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formatPrice(s.pricePerHour),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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
          ),
        ],
      ),
    );
  }
}

class StadiumDetailScreen extends ConsumerStatefulWidget {
  const StadiumDetailScreen({super.key, required this.stadiumId});

  final int stadiumId;

  @override
  ConsumerState<StadiumDetailScreen> createState() => _StadiumDetailScreenState();
}

class _StadiumDetailScreenState extends ConsumerState<StadiumDetailScreen> {
  DateTime _date = DateTime.now();
  String? _slot;
  int _duration = 1;
  Availability? _availability;
  bool _loadingSlots = false;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSlots);
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slot = null;
    });
    try {
      final a = await ref
          .read(apiClientProvider)
          .stadiumAvailability(widget.stadiumId, _dateStr);
      if (mounted) {
        setState(() {
          _availability = a;
          _loadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSlots = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _loadSlots();
    }
  }

  Future<void> _book(Stadium stadium) async {
    if (_slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vaqt tanlang')),
      );
      return;
    }
    setState(() => _booking = true);
    try {
      final booking = await ref.read(apiClientProvider).createBooking(
            stadiumId: stadium.id,
            date: _dateStr,
            startTime: _slot!,
            durationHours: _duration,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bron yaratildi · ${formatPrice(booking.totalPrice)}')),
      );
      context.push('/app/bookings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stadiumDetailProvider(widget.stadiumId));

    return Scaffold(
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(stadiumDetailProvider(widget.stadiumId)),
        ),
        data: (stadium) {
          final slots = _availability?.slots ?? const <AvailabilitySlot>[];
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    stadium.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  background: PcNetworkImage(url: stadium.imageUrl),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stadium.district} · ⭐ ${stadium.rating.toStringAsFixed(1)} (${stadium.reviewsCount})',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${formatPrice(stadium.pricePerHour)} / soat',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(stadium.address, style: const TextStyle(color: AppColors.muted)),
                      if (stadium.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(stadium.description),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(label: stadium.surface),
                          _Chip(label: stadium.size),
                          if (stadium.hasShower) const _Chip(label: 'Dush'),
                          if (stadium.hasParking) const _Chip(label: 'Parking'),
                          if (stadium.hasLighting) const _Chip(label: 'Yoritish'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Bron qilish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sana'),
                        subtitle: Text(_dateStr),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 8),
                      const Text('Davomiylik', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [1, 2, 3].map((h) {
                          final selected = _duration == h;
                          return ChoiceChip(
                            label: Text('$h soat'),
                            selected: selected,
                            onSelected: (_) => setState(() => _duration = h),
                            selectedColor: AppColors.primary.withValues(alpha: 0.25),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Vaqt', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (_loadingSlots)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: LoadingView(),
                        )
                      else if (slots.isEmpty)
                        const Text('Bo‘sh slot yo‘q', style: TextStyle(color: AppColors.muted))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: slots.map((s) {
                            final selected = _slot == s.startTime;
                            return ChoiceChip(
                              label: Text(s.startTime),
                              selected: selected,
                              onSelected: !s.available
                                  ? null
                                  : (_) => setState(() => _slot = s.startTime),
                              selectedColor: AppColors.primary.withValues(alpha: 0.25),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _booking ? null : () => _book(stadium),
                        child: _booking
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Bron qilish · ${formatPrice(stadium.pricePerHour * _duration)}',
                              ),
                      ),
                      const SizedBox(height: 32),
                    ],
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.edge),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }
}
