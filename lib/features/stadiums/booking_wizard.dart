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

/// Toza bron oqimi — sana/vaqt oralig‘i → zakalat.
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
  String? _slot; // range start HH:mm
  int _duration = 1;
  Availability? _availability;
  bool _loadingSlots = false;
  bool _booking = false;
  bool _daytimeOpen = false;
  XFile? _proof;
  int? _createdBookingId;

  Stadium get stadium => widget.stadium;
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  late final List<DateTime> _dates;

  static const _dayNames = [
    'Dushanba',
    'Seshanba',
    'Chorshanba',
    'Payshanba',
    'Juma',
    'Shanba',
    'Yakshanba',
  ];
  static const _dayShort = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _monthUz = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentabr',
    'oktabr',
    'noyabr',
    'dekabr',
  ];

  /// Oy bo‘yicha yengil rang — oy nomini har sanaga yozmasdan ajratish.
  static const _monthAccents = <Color>[
    Color(0xFF5B8DEF), // yan
    Color(0xFFE879A9), // fev
    Color(0xFF12B76A), // mar
    Color(0xFFF5A524), // apr
    Color(0xFF22D3A6), // may
    Color(0xFFA78BFA), // iyn
    Color(0xFFFB7185), // iyl
    Color(0xFF34D399), // avg
    Color(0xFFFBBF24), // sen
    Color(0xFF60A5FA), // okt
    Color(0xFFF472B6), // noy
    Color(0xFF2DD4BF), // dek
  ];

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date = DateTime(n.year, n.month, n.day);
    _dates = List.generate(30, (i) => _date.add(Duration(days: i)));
    Future.microtask(_loadSlots);
  }

  String _norm(String t) {
    final p = t.split(':');
    final h = int.tryParse(p.isNotEmpty ? p[0] : '0') ?? 0;
    final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int _hourOf(String t) => int.parse(_norm(t).split(':')[0]);

  String _endTime(String start, int hours) {
    final parts = _norm(start).split(':');
    final total = (int.parse(parts[0]) * 60 + int.parse(parts[1]) + hours * 60)
        .clamp(0, 23 * 60 + 59);
    return _norm('${total ~/ 60}:${total % 60}');
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _prettyDate(DateTime d) => '${d.day}-${_monthUz[d.month - 1]}';

  String _formatCard(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  Map<String, bool> get _slotMap {
    final map = <String, bool>{};
    for (final s in _availability?.slots ?? const <AvailabilitySlot>[]) {
      map[_norm(s.startTime)] = s.available;
    }
    return map;
  }

  List<AvailabilitySlot> get _allSlots =>
      _availability?.slots ?? const <AvailabilitySlot>[];

  bool _rangeFree(String start, int hours) {
    final byTime = _slotMap;
    final h0 = _hourOf(start);
    final m = _norm(start).split(':')[1];
    for (var i = 0; i < hours; i++) {
      if (byTime[_norm('${h0 + i}:$m')] != true) return false;
    }
    return true;
  }

  void _onTapHour(String time) {
    final t = _norm(time);
    final available = _slotMap[t] == true;
    if (!available) {
      _snack('Bu vaqt band');
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      if (_slot == null) {
        _slot = t;
        _duration = 1;
        return;
      }
      final startH = _hourOf(_slot!);
      final tapH = _hourOf(t);
      if (tapH < startH) {
        _slot = t;
        _duration = 1;
        return;
      }
      if (tapH == startH) {
        _slot = null;
        _duration = 1;
        return;
      }
      final hours = tapH - startH + 1;
      if (hours > 12) {
        _snack('Maksimal 12 soat');
        return;
      }
      if (!_rangeFree(_slot!, hours)) {
        _snack('Oraliqda band soat bor — boshqa oralik tanlang');
        return;
      }
      _duration = hours;
    });
  }

  bool _inSelectedRange(String time) {
    if (_slot == null) return false;
    final h = _hourOf(time);
    final start = _hourOf(_slot!);
    return h >= start && h < start + _duration;
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slot = null;
      _duration = 1;
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

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll(' ', '')));
    HapticFeedback.lightImpact();
    _snack('Karta raqami nusxalandi');
  }

  Future<void> _copyTransferCode() async {
    final id = _createdBookingId;
    if (id == null) return;
    final code = 'BRON-$id';
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    _snack('Bron kodi nusxalandi: $code');
  }

  Future<void> _goToPayStep() async {
    if (_slot == null || _booking) return;
    // Avval UI ochiladi — API kutish ekranni “muzlatmasin”
    setState(() {
      _step = 1;
      _booking = true;
    });
    final api = ref.read(apiClientProvider);
    final start = _norm(_slot!);
    try {
      if (_createdBookingId != null) {
        try {
          await api.cancelBooking(_createdBookingId!);
        } catch (_) {}
        _createdBookingId = null;
      }
      final created = await api.createBooking(
        stadiumId: stadium.id,
        date: _dateStr,
        startTime: start,
        durationHours: _duration,
      );
      if (!mounted) return;
      setState(() {
        _createdBookingId = created.id;
        _booking = false;
      });
    } catch (e) {
      final msg = '$e';
      if (msg.contains('slot_taken') ||
          msg.toLowerCase().contains('band') ||
          (e is ApiException && e.statusCode == 409)) {
        _snack('Bu vaqt band — boshqa oralik tanlang');
        await _loadSlots();
      } else {
        _snack(msg);
      }
      if (mounted) {
        setState(() {
          _step = 0;
          _booking = false;
        });
      }
    }
  }

  Future<void> _backFromPay() async {
    final id = _createdBookingId;
    if (id != null) {
      try {
        await ref.read(apiClientProvider).cancelBooking(id);
      } catch (_) {}
      _createdBookingId = null;
    }
    setState(() {
      _step = 0;
      _proof = null;
    });
  }

  Future<void> _pay() async {
    if (_slot == null || _booking) return;
    if (_proof == null) {
      _snack('Avval to‘lov chekini yuklang');
      return;
    }
    final bookingId = _createdBookingId;
    if (bookingId == null) {
      _snack('Bron yaratilmadi — orqaga qaytib qayta urining');
      return;
    }
    setState(() => _booking = true);
    final api = ref.read(apiClientProvider);
    HapticFeedback.mediumImpact();

    try {
      final proof = await api.uploadBookingPaymentProof(
        bookingId: bookingId,
        filePath: _proof!.path,
        fileName: _proof!.name,
      );
      if (!mounted) return;

      final deposit = stadium.depositFor(stadium.pricePerHour * _duration);
      final auth = proof['payment_proof_authenticity'];
      final statusLabel =
          proof['payment_proof_check_status_label']?.toString() ?? '';
      final disclaimer = proof['disclaimer']?.toString();

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
                  if (auth != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'To‘g‘rilik ehtimoli: $auth%${statusLabel.isNotEmpty ? ' — $statusLabel' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Zakalat ${formatPrice(deposit)} — egasi chekni tasdiqlagach bron ochiladi.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  if (disclaimer != null && disclaimer.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      disclaimer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.faint,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
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
        _snack('Bu vaqt band — boshqa oralik tanlang');
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
    final rangeLabel = _slot == null
        ? null
        : '${_prettyDate(_date)} · ${_norm(_slot!)}–${_endTime(_slot!, _duration)}';

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
                      _backFromPay();
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
                        _step == 0
                            ? (rangeLabel ?? 'Sana va vaqt oralig‘i')
                            : 'To‘lov · ${_prettyDate(_date)}',
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
                const Expanded(child: _StepBar(active: true, label: '1')),
                const SizedBox(width: 8),
                Expanded(child: _StepBar(active: _step >= 1, label: '2')),
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
                            _snack('Vaqt oralig‘ini tanlang');
                            return;
                          }
                          HapticFeedback.selectionClick();
                          _goToPayStep();
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
                                : 'Davom · ${_prettyDate(_date)} · ${formatPrice(total)}')
                            : (_proof == null
                                ? 'Chekni yuklang'
                                : 'Yuborish · ${formatPrice(deposit)}'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
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
    final all = _allSlots;
    final evening = all.where((s) => _hourOf(s.startTime) >= 16).toList();
    final daytime = all.where((s) => _hourOf(s.startTime) < 16).toList();
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          children: [
            const Text(
              'Qaysi kuni?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
            Text(
              _monthUz[_date.month - 1],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _monthAccents[_date.month - 1],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = _dates[i];
              final sel = _sameDay(d, _date);
              final isToday = _sameDay(d, now);
              final isTomorrow = _sameDay(d, tomorrow);
              final accent = _monthAccents[d.month - 1];
              final label = isToday
                  ? 'Bugun'
                  : isTomorrow
                      ? 'Ertaga'
                      : _dayShort[d.weekday - 1];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _date = d);
                  _loadSlots();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: sel ? accent : AppColors.surface,
                    border: Border.all(
                      color: sel ? accent : accent.withValues(alpha: 0.35),
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: sel ? const Color(0xFF0A120E) : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: sel
                              ? const Color(0xFF0A120E).withValues(alpha: 0.75)
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
        const SizedBox(height: 8),
        Text(
          _dayNames[_date.weekday - 1],
          style: const TextStyle(color: AppColors.faint, fontSize: 12),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Bo‘sh vaqtlar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
            if (_slot != null)
              Text(
                '${_norm(_slot!)} – ${_endTime(_slot!, _duration)}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Boshlanish va tugash soatini bosing (masalan 18→21)',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (_loadingSlots)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (all.isEmpty)
          _emptyTimes()
        else ...[
          if (evening.isNotEmpty) ...[
            const Text(
              'Asosiy · 16:00 dan',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            _timeGrid(evening, prominent: true),
          ],
          if (daytime.isNotEmpty) ...[
            const SizedBox(height: 14),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _daytimeOpen = !_daytimeOpen),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Kunduzgi vaqtlar · ${daytime.length} ta',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        _daytimeOpen
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_daytimeOpen) ...[
              const SizedBox(height: 10),
              _timeGrid(daytime, prominent: false),
            ],
          ],
        ],
      ],
    );
  }

  Widget _emptyTimes() {
    return Container(
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
            'Bu kunda slot yo‘q',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Boshqa kunni tanlang',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _timeGrid(List<AvailabilitySlot> slots, {required bool prominent}) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final cols = 4;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in slots)
              SizedBox(
                width: w,
                child: _TimeChip(
                  time: _norm(s.startTime),
                  available: s.available,
                  selected: _inSelectedRange(s.startTime),
                  prominent: prominent,
                  onTap: () => _onTapHour(s.startTime),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStepPay({
    Key? key,
    required int total,
    required int deposit,
  }) {
    final start = _slot ?? '--:--';
    final end = _slot != null ? _endTime(_slot!, _duration) : '--:--';
    final dayLabel = _prettyDate(_date);
    final rawCard = stadium.payoutCardNumber?.replaceAll(RegExp(r'\s+'), '');
    final cardPretty =
        rawCard != null && rawCard.isNotEmpty ? _formatCard(rawCard) : null;
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
                    'Zakalat',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    formatPrice(deposit),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              if (deposit < total) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Jami ${formatPrice(total)} · qolgani maydonda',
                    style: const TextStyle(color: AppColors.faint, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Bron kodi — o‘tkazma izohiga
        if (_createdBookingId != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'O‘tkazma izohiga yozing',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'BRON-$_createdBookingId',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _copyTransferCode,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Nusxa'),
                    ),
                  ],
                ),
                const Text(
                  'Shu kodni to‘lov izohiga qo‘ying — egasi va AI tekshiruvi osonlashadi.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        // Prominent copyable card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface2, AppColors.bg],
            ),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.55), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.credit_card_rounded,
                      color: AppColors.primarySoft, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Shu kartaga o‘tkazing',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.primarySoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (cardPretty != null) ...[
                SelectableText(
                  cardPretty,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1.2,
                    height: 1.2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (holder != null && holder.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    holder,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _copyCard(rawCard!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF052E12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      'Raqamni nusxalash',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ] else
                const Text(
                  'Karta hali kiritilmagan — egasi bilan bog‘laning',
                  style: TextStyle(color: AppColors.muted, height: 1.35),
                ),
              const SizedBox(height: 10),
              const Text(
                'Pul o‘tkazib, chek rasmini yuklang — egaga Telegram orqali foiz bilan keladi.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
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

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.available,
    required this.selected,
    required this.prominent,
    required this.onTap,
  });

  final String time;
  final bool available;
  final bool selected;
  final bool prominent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final booked = !available;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: prominent ? 48 : 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.gold
              : booked
                  ? const Color(0xFF2A1216)
                  : AppColors.surface2,
          border: Border.all(
            color: selected
                ? AppColors.gold
                : booked
                    ? const Color(0xFFE11D48).withValues(alpha: 0.55)
                    : AppColors.edge,
          ),
        ),
        child: Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: prominent ? 14 : 13,
            decoration: booked ? TextDecoration.lineThrough : null,
            decorationColor: const Color(0xFFE11D48),
            color: selected
                ? const Color(0xFF1A1000)
                : booked
                    ? const Color(0xFFE11D48)
                    : AppColors.ink,
          ),
        ),
      ),
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
