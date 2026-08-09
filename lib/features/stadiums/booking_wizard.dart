import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/analytics.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format.dart';
import '../../shared/models/models.dart';

/// Toza bron oqimi — sana/vaqt → zakalat.
Future<void> openBookingWizard(
  BuildContext context, {
  required Stadium stadium,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BookingSheet(stadium: stadium),
  );
}

class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({super.key, required this.stadium});
  final Stadium stadium;

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  int _step = 0; // 0 = vaqt, 1 = to‘lov
  late DateTime _date;
  String? _slot;
  int _duration = 1;
  Availability? _availability;
  bool _loadingSlots = false;
  bool _booking = false;
  XFile? _proof;

  Stadium get stadium => widget.stadium;
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  late final List<DateTime> _dates;

  static const _dayNames = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date = DateTime(n.year, n.month, n.day);
    _dates = List.generate(14, (i) => _date.add(Duration(days: i)));
    Future.microtask(_loadSlots);
  }

  String _norm(String t) {
    final p = t.split(':');
    final h = int.tryParse(p.isNotEmpty ? p[0] : '0') ?? 0;
    final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _endTime(String start, int hours) {
    final parts = _norm(start).split(':');
    final total = (int.parse(parts[0]) * 60 + int.parse(parts[1]) + hours * 60)
        .clamp(0, 23 * 60 + 59);
    return _norm('${total ~/ 60}:${total % 60}');
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _contiguousFree(String start) {
    final byTime = {
      for (final s in _availability?.slots ?? const <AvailabilitySlot>[])
        _norm(s.startTime): s.available,
    };
    final parts = _norm(start).split(':');
    var h = int.parse(parts[0]);
    final m = parts[1];
    for (var i = 0; i < _duration; i++) {
      if (byTime[_norm('${h + i}:$m')] != true) return false;
    }
    return true;
  }

  List<String> get _slots {
    final raw = _availability?.slots ?? const <AvailabilitySlot>[];
    return raw
        .where((s) => s.available && _contiguousFree(s.startTime))
        .map((s) => _norm(s.startTime))
        .toList();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slot = null;
    });
    try {
      final a = await ref
          .read(apiClientProvider)
          .stadiumAvailability(stadium.id, _dateStr);
      if (!mounted) return;
      setState(() {
        _availability = a;
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSlots = false);
      _snack('$e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickProof() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    setState(() => _proof = file);
  }

  Future<void> _pay() async {
    if (_slot == null || _booking) return;
    if (_proof == null) {
      _snack('Avval to‘lov chekini yuklang');
      return;
    }
    setState(() => _booking = true);
    final api = ref.read(apiClientProvider);
    final start = _norm(_slot!);
    HapticFeedback.mediumImpact();

    try {
      // create → chek → egasi tasdiqlamaguncha zakalat qabul qilinmaydi
      final created = await api.createBooking(
        stadiumId: stadium.id,
        date: _dateStr,
        startTime: start,
        durationHours: _duration,
      );
      await api.uploadBookingPaymentProof(
        bookingId: created.id,
        filePath: _proof!.path,
        fileName: _proof!.name,
      );
      if (!mounted) return;

      final bookingId = created.id;
      final deposit = stadium.depositFor(stadium.pricePerHour * _duration);

      Analytics.log('booking_proof_sent', {'id': '$bookingId'});

      if (!mounted) return;
      final router = GoRouter.of(context);
      final rootNav = Navigator.of(context, rootNavigator: true);
      Navigator.of(context).pop();

      await showDialog<void>(
        context: rootNav.context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            backgroundColor: AppColors.surface,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.hourglass_top_rounded,
                        color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chek yuborildi',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zakalat ${formatPrice(deposit)} — stadion egasi chekni ko‘rib tasdiqlagach bron ochiladi.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        router.push('/app/bookings');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF003D26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Bronlarim',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Yopish'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      final msg = '$e';
      if (msg.contains('slot_taken') ||
          msg.toLowerCase().contains('band') ||
          (e is ApiException && e.statusCode == 409)) {
        _snack('Bu vaqt band — boshqa slot tanlang');
        await _loadSlots();
      } else {
        _snack(msg);
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final pad = MediaQuery.paddingOf(context);
    final total = stadium.pricePerHour * _duration;
    final deposit = stadium.depositFor(total);

    return Container(
      height: h * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_step > 0) {
                      setState(() => _step = 0);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(
                    _step > 0 ? Icons.arrow_back_rounded : Icons.close_rounded,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stadium.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _step == 0 ? 'Sana va vaqt' : 'To‘lov va chek',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _StepBar(active: true, label: '1'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StepBar(active: _step >= 1, label: '2'),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _step == 0
                  ? _buildStepTime(key: const ValueKey('time'))
                  : _buildStepPay(
                      key: const ValueKey('pay'),
                      total: total,
                      deposit: deposit,
                    ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + pad.bottom),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.98),
              border: const Border(
                top: BorderSide(color: AppColors.edge),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _booking
                    ? null
                    : () {
                        if (_step == 0) {
                          if (_slot == null) {
                            _snack('Vaqt tanlang');
                            return;
                          }
                          HapticFeedback.selectionClick();
                          setState(() => _step = 1);
                        } else {
                          _pay();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF1A1000),
                  disabledBackgroundColor: AppColors.edge,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _booking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF1A1000),
                        ),
                      )
                    : Text(
                        _step == 0
                            ? (_slot == null
                                ? 'Vaqt tanlang'
                                : 'Davom · ${formatPrice(total)}')
                            : (_proof == null
                                ? 'Chekni yuklang'
                                : 'To‘lash · ${formatPrice(total)}'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTime({Key? key}) {
    final slots = _slots;
    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const Text(
          'Qaysi kuni?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = _dates[i];
              final sel = _sameDay(d, _date);
              final today = _sameDay(d, DateTime.now());
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _date = d);
                  _loadSlots();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: sel ? AppColors.gold : AppColors.surface,
                    border: Border.all(
                      color: sel ? AppColors.gold : AppColors.edge,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        today ? 'Bugun' : _dayNames[d.weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? const Color(0xFF1A1000)
                              : AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: sel
                              ? const Color(0xFF1A1000)
                              : AppColors.ink,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(d),
                        style: TextStyle(
                          fontSize: 10,
                          color: sel
                              ? const Color(0xFF1A1000).withValues(alpha: 0.65)
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Necha soat?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final h in [1, 2, 3]) ...[
              if (h > 1) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _duration = h;
                      if (_slot != null && !_contiguousFree(_slot!)) {
                        _slot = null;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _duration == h
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surface,
                      border: Border.all(
                        color: _duration == h
                            ? AppColors.primary
                            : AppColors.edge,
                        width: _duration == h ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      '$h soat',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _duration == h
                            ? AppColors.primary
                            : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text(
              'Bo‘sh vaqt',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
            if (!_loadingSlots)
              Text(
                '${slots.length} ta',
                style: const TextStyle(color: AppColors.faint, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingSlots)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (slots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.edge),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_busy_rounded, color: AppColors.faint, size: 32),
                SizedBox(height: 8),
                Text(
                  'Bo‘sh slot yo‘q',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Boshqa kun yoki 1 soatni tanlang',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              const gap = 8.0;
              final cols = 3;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in slots)
                    SizedBox(
                      width: w,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _slot = s);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _slot == s
                                ? AppColors.gold
                                : AppColors.surface2,
                            border: Border.all(
                              color: _slot == s
                                  ? AppColors.gold
                                  : AppColors.edge,
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _slot == s
                                  ? const Color(0xFF1A1000)
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildStepPay({
    Key? key,
    required int total,
    required int deposit,
  }) {
    final start = _slot ?? '--:--';
    final end = _slot != null ? _endTime(_slot!, _duration) : '--:--';
    final dayLabel = '${_date.day}.${_date.month}.${_date.year}';
    final card = stadium.payoutCardMasked;
    final holder = stadium.payoutCardHolder;

    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2A1F), Color(0xFF0D1A12)],
            ),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stadium.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              _payRow(Icons.calendar_today_rounded, 'Sana', dayLabel),
              const SizedBox(height: 10),
              _payRow(Icons.schedule_rounded, 'Vaqt', '$start – $end'),
              const SizedBox(height: 10),
              _payRow(Icons.timelapse_rounded, 'Davomiylik', '$_duration soat'),
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.edge),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'To‘lov summasi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    formatPrice(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.edge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Egasi kartasi',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                card ?? 'Karta hali kiritilmagan — egasi bilan bog‘laning',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: card == null ? AppColors.muted : AppColors.ink,
                ),
              ),
              if (holder != null && holder.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(holder, style: const TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 8),
              const Text(
                'Pul o‘tkazing, keyin chek rasmini yuklang — u to‘g‘ridan-to‘g‘ri stadion egasiga boradi.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _booking ? null : _pickProof,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _proof != null ? AppColors.gold : AppColors.edge,
                width: _proof != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (_proof != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_proof!.path),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.muted),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _proof == null
                            ? 'To‘lov chekini yuklash'
                            : 'Chek tanlandi',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _proof == null
                            ? 'Galereyadan rasm tanlang'
                            : _proof!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _proof == null
                      ? Icons.add_photo_alternate_outlined
                      : Icons.check_circle_rounded,
                  color: _proof == null ? AppColors.muted : AppColors.gold,
                ),
              ],
            ),
          ),
        ),
        if (deposit > 0 && deposit < total) ...[
          const SizedBox(height: 12),
          Text(
            'Eslatma: zakalat ${formatPrice(deposit)}, qolgani maydonda.',
            style: const TextStyle(color: AppColors.faint, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _payRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.active, required this.label});
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: active ? AppColors.gold : AppColors.edge,
      ),
    );
  }
}
