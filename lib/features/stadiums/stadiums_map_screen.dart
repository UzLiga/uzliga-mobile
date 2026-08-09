import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'booking_wizard.dart';

final mapStadiumsProvider = FutureProvider((ref) {
  return ref.watch(apiClientProvider).listStadiums(limit: 40, sort: '-rating');
});

class StadiumsMapScreen extends ConsumerStatefulWidget {
  const StadiumsMapScreen({super.key});

  @override
  ConsumerState<StadiumsMapScreen> createState() => _StadiumsMapScreenState();
}

class _StadiumsMapScreenState extends ConsumerState<StadiumsMapScreen> {
  final _map = MapController();
  LatLng? _me;
  Stadium? _selected;
  String? _geoError;
  bool _locating = false;

  static const _tashkent = LatLng(41.3111, 69.2797);

  /// O‘zbekiston bounding box — xarita butun dunyoga zoom out qilmasin.
  static final _uzBounds = LatLngBounds(
    const LatLng(37.0, 55.9),
    const LatLng(45.6, 73.2),
  );
  static const _minZoom = 5.8;
  static const _maxZoom = 16.5;

  bool _inUz(LatLng p) =>
      p.latitude >= 37.0 &&
      p.latitude <= 45.6 &&
      p.longitude >= 55.9 &&
      p.longitude <= 73.2;

  LatLng _clampUz(LatLng p) {
    if (_inUz(p)) return p;
    return _tashkent;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_locate);
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _geoError = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _geoError = 'Joylashuv ruxsati yo‘q';
          _locating = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final raw = LatLng(pos.latitude, pos.longitude);
      final me = _clampUz(raw);
      setState(() {
        _me = me;
        _locating = false;
        if (!_inUz(raw)) {
          _geoError = 'Joylashuv UZ tashqarisida — Toshkentga qaytdik';
        }
      });
      _map.move(me, 12.5);
    } catch (e) {
      setState(() {
        _geoError = 'Joylashuv olinmadi';
        _locating = false;
      });
    }
  }

  double? _km(Stadium s) {
    if (_me == null || s.lat == null || s.lng == null) return null;
    return Geolocator.distanceBetween(
          _me!.latitude,
          _me!.longitude,
          s.lat!,
          s.lng!,
        ) /
        1000.0;
  }

  void _select(Stadium s) {
    HapticFeedback.selectionClick();
    setState(() => _selected = s);
    if (s.lat != null && s.lng != null) {
      _map.move(LatLng(s.lat!, s.lng!), 14.5);
    }
  }

  Future<void> _book(Stadium s) async {
    // Prefer fresh detail (deposit rules etc.)
    try {
      final full = await ref.read(apiClientProvider).getStadium(s.id);
      if (!mounted) return;
      await openBookingWizard(context, stadium: full);
    } catch (_) {
      if (!mounted) return;
      await openBookingWizard(context, stadium: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mapStadiumsProvider);

    return Scaffold(
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(mapStadiumsProvider),
        ),
        data: (page) {
          final withGeo = page.items
              .where((s) => s.lat != null && s.lng != null)
              .toList();
          if (_me != null) {
            withGeo.sort((a, b) {
              final da = _km(a) ?? 9999;
              final db = _km(b) ?? 9999;
              return da.compareTo(db);
            });
          }
          final center = _me ??
              (withGeo.isNotEmpty
                  ? LatLng(withGeo.first.lat!, withGeo.first.lng!)
                  : _tashkent);

          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 11.5,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: _uzBounds,
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, __) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'tech.asilbek.playzon',
                    maxNativeZoom: 18,
                    keepBuffer: 2,
                    panBuffer: 1,
                  ),
                  MarkerLayer(
                    markers: [
                      if (_me != null)
                        Marker(
                          point: _me!,
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ...withGeo.map((s) {
                        final sel = _selected?.id == s.id;
                        return Marker(
                          point: LatLng(s.lat!, s.lng!),
                          width: sel ? 44 : 36,
                          height: sel ? 44 : 36,
                          child: GestureDetector(
                            onTap: () => _select(s),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary
                                    : const Color(0xFF0B221A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel
                                      ? AppColors.lime
                                      : AppColors.primary,
                                  width: sel ? 2.5 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (sel
                                            ? AppColors.lime
                                            : AppColors.primary)
                                        .withValues(alpha: 0.35),
                                    blurRadius: sel ? 10 : 6,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.sports_soccer,
                                size: sel ? 20 : 16,
                                color: sel
                                    ? const Color(0xFF003D26)
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              const Positioned(left: 0, top: 0, child: PcBackChip()),
              Positioned(
                right: 12,
                top: MediaQuery.of(context).padding.top + 8,
                child: Column(
                  children: [
                    _RoundBtn(
                      icon: _locating
                          ? Icons.hourglass_top
                          : Icons.my_location,
                      onTap: _locating ? null : _locate,
                    ),
                    const SizedBox(height: 8),
                    _RoundBtn(
                      icon: Icons.list_alt,
                      onTap: () => context.push('/app/stadiums'),
                    ),
                  ],
                ),
              ),
              if (_geoError != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 56,
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _geoError!,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
              // Default nearby list (when nothing selected)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                bottom: _selected == null ? 0 : -420,
                child: _NearbyListSheet(
                  stadiums: withGeo.take(12).toList(),
                  kmOf: _km,
                  onSelect: _select,
                ),
              ),
              // Place card for selected pin
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                bottom: _selected != null ? 0 : -360,
                child: _selected == null
                    ? const SizedBox.shrink()
                    : _PlaceCardSheet(
                        stadium: _selected!,
                        km: _km(_selected!),
                        onClose: () => setState(() => _selected = null),
                        onOpen: () =>
                            context.push('/app/stadiums/${_selected!.id}'),
                        onBook: () => _book(_selected!),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg.withValues(alpha: 0.8),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.ink),
      ),
    );
  }
}

class _NearbyListSheet extends StatelessWidget {
  const _NearbyListSheet({
    required this.stadiums,
    required this.kmOf,
    required this.onSelect,
  });

  final List<Stadium> stadiums;
  final double? Function(Stadium) kmOf;
  final ValueChanged<Stadium> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.34,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: AppColors.edge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.edge,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Yaqin stadionlar',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${stadiums.length} ta',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: math.min(stadiums.length, 12),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = stadiums[i];
                final km = kmOf(s);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => onSelect(s),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: PcNetworkImage(url: s.imageUrl),
                    ),
                  ),
                  title: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      s.district,
                      if (km != null) '${km.toStringAsFixed(1)} km',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    formatPrice(s.pricePerHour),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
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

/// Apple Maps–style edge place card — image, price, rating, Bron.
class _PlaceCardSheet extends StatelessWidget {
  const _PlaceCardSheet({
    required this.stadium,
    required this.onClose,
    required this.onOpen,
    required this.onBook,
    this.km,
  });

  final Stadium stadium;
  final double? km;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.fromLTRB(12, 0, 12, bottom + 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2A1F), Color(0xFF0B1510)],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PcNetworkImage(url: stadium.imageUrl),
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
                    right: 8,
                    top: 8,
                    child: IconButton(
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    right: 14,
                    child: Text(
                      stadium.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 16, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            stadium.district,
                            if (km != null) '${km!.toStringAsFixed(1)} km',
                          ].join(' · '),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.star_rounded,
                          size: 16, color: AppColors.gold),
                      const SizedBox(width: 2),
                      Text(
                        stadium.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatPrice(stadium.pricePerHour),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        ' / soat',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: onOpen,
                        child: const Text('Batafsil'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF1A1000),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text(
                        'Bron qilish',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
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
