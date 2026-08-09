import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'booking_wizard.dart';

class StadiumsFilter {
  const StadiumsFilter({
    this.search = '',
    this.district,
    this.minPrice,
    this.maxPrice,
    this.sort = '-rating',
  });

  final String search;
  final String? district;
  final int? minPrice;
  final int? maxPrice;
  final String sort;

  StadiumsFilter copyWith({
    String? search,
    String? district,
    int? minPrice,
    int? maxPrice,
    String? sort,
    bool clearDistrict = false,
    bool clearPrices = false,
  }) {
    return StadiumsFilter(
      search: search ?? this.search,
      district: clearDistrict ? null : (district ?? this.district),
      minPrice: clearPrices ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrices ? null : (maxPrice ?? this.maxPrice),
      sort: sort ?? this.sort,
    );
  }
}

final stadiumsFilterProvider =
    NotifierProvider<StadiumsFilterNotifier, StadiumsFilter>(
  StadiumsFilterNotifier.new,
);

class StadiumsFilterNotifier extends Notifier<StadiumsFilter> {
  @override
  StadiumsFilter build() => const StadiumsFilter();

  void setSearch(String v) => state = state.copyWith(search: v);
  void setDistrict(String? d) =>
      state = state.copyWith(district: d, clearDistrict: d == null);
  void setPriceRange(int? min, int? max) =>
      state = state.copyWith(minPrice: min, maxPrice: max, clearPrices: min == null && max == null);
  void setSort(String s) => state = state.copyWith(sort: s);
}

final districtsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).districts();
});

final stadiumsProvider = FutureProvider((ref) {
  final f = ref.watch(stadiumsFilterProvider);
  return ref.watch(apiClientProvider).listStadiums(
        search: f.search,
        district: f.district,
        minPrice: f.minPrice,
        maxPrice: f.maxPrice,
        sort: f.sort,
        limit: 24,
      );
});

final stadiumDetailProvider =
    FutureProvider.autoDispose.family<Stadium, int>((ref, id) {
  return ref.watch(apiClientProvider).getStadium(id);
});

class StadiumsScreen extends ConsumerWidget {
  const StadiumsScreen({super.key});

  static const _pricePresets = <(String, int?, int?)>[
    ('Hammasi', null, null),
    ('< 100k', null, 100000),
    ('100–200k', 100000, 200000),
    ('200k+', 200000, null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stadiumsProvider);
    final filter = ref.watch(stadiumsFilterProvider);
    final districts = ref.watch(districtsProvider);

    return Scaffold(
      appBar: pcAppBar(
        context,
        title: 'Stadionlar',
        actions: [
          IconButton(
            tooltip: 'Xarita',
            onPressed: () => context.push('/app/map'),
            icon: const Icon(Icons.map_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Saralash',
            initialValue: filter.sort,
            onSelected: (v) =>
                ref.read(stadiumsFilterProvider.notifier).setSort(v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: '-rating', child: Text('Reyting')),
              PopupMenuItem(value: 'price_per_hour', child: Text('Narx ↑')),
              PopupMenuItem(value: '-price_per_hour', child: Text('Narx ↓')),
              PopupMenuItem(value: 'name', child: Text('Nom')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) =>
                  ref.read(stadiumsFilterProvider.notifier).setSearch(v),
              decoration: const InputDecoration(
                hintText: 'Stadion qidirish...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: districts.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                final chips = <String?>[null, ...list];
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final d = chips[i];
                    final selected = filter.district == d;
                    return FilterChip(
                      label: Text(d ?? 'Barcha tuman'),
                      selected: selected,
                      onSelected: (_) => ref
                          .read(stadiumsFilterProvider.notifier)
                          .setDistrict(d),
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                      checkmarkColor: AppColors.primary,
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.edge,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _pricePresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = _pricePresets[i];
                final selected =
                    filter.minPrice == p.$2 && filter.maxPrice == p.$3;
                return ChoiceChip(
                  label: Text(p.$1, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(stadiumsFilterProvider.notifier)
                      .setPriceRange(p.$2, p.$3),
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(stadiumsProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyState(
                    title: 'Stadion topilmadi',
                    subtitle: 'Filtrlarni o‘zgartiring',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(stadiumsProvider);
                    ref.invalidate(districtsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final s = page.items[i];
                      return _StadiumCard(stadium: s);
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

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({required this.stadium});
  final Stadium stadium;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/app/stadiums/${stadium.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.edge),
            color: AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PcNetworkImage(url: stadium.imageUrl),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '⭐ ${stadium.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            formatPrice(stadium.pricePerHour),
                            style: const TextStyle(
                              color: Color(0xFF052E12),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stadium.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stadium.district} · ${stadium.size} · ${stadium.surface}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StadiumDetailScreen extends ConsumerWidget {
  const StadiumDetailScreen({super.key, required this.stadiumId});

  final int stadiumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stadiumDetailProvider(stadiumId));

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: async.hasValue ? const PcBackChip() : null,
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(stadiumDetailProvider(stadiumId)),
        ),
        data: (stadium) {
          final depositHint =
              stadium.depositFor(stadium.pricePerHour);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    stadium.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PcNetworkImage(url: stadium.imageUrl),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xCC0B1510)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stadium.district} · ${formatPrice(stadium.pricePerHour)}/soat',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(stadium.address,
                          style: const TextStyle(color: AppColors.muted)),
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
                          if (stadium.hasLighting)
                            const _Chip(label: 'Yoritish'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A2A1F), Color(0xFF0B1510)],
                          ),
                          border: Border.all(
                            color: const Color(0xFFE8B923)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bron qilish',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sana va vaqtni tanlang, zakalat bilan bron ochiladi.\n'
                              'Zakalat taxminan ${formatPrice(depositHint)} / soat',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => openBookingWizard(
                                  context,
                                  stadium: stadium,
                                ),
                                icon: const Icon(Icons.event_available),
                                label: const Text('Bron qilish'),
                              ),
                            ),
                          ],
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
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

