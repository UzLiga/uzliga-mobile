import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../format.dart';
import '../models/models.dart';
import 'widgets.dart';

/// Matchday-style bron ticket (gold foil + QR).
class BookingTicket extends StatelessWidget {
  const BookingTicket({
    super.key,
    required this.stadiumName,
    required this.date,
    required this.startTime,
    required this.durationHours,
    this.bookingId,
    this.imageUrl,
    this.priceLabel,
    this.statusLabel,
    this.qrPayload,
    this.subtitle,
    this.compact = false,
  });

  final String stadiumName;
  final String date;
  final String startTime;
  final int durationHours;
  final int? bookingId;
  final String? imageUrl;
  final String? priceLabel;
  final String? statusLabel;
  final String? qrPayload;
  final String? subtitle;
  final bool compact;

  factory BookingTicket.fromBooking(
    Booking b, {
    String? qrPayload,
    bool compact = false,
  }) {
    return BookingTicket(
      stadiumName: b.stadium.name,
      date: b.date,
      startTime: b.startTime,
      durationHours: b.durationHours,
      bookingId: b.id,
      imageUrl: b.stadium.imageUrl,
      priceLabel: formatPrice(b.totalPrice),
      statusLabel: bookingStatusLabel(b.status),
      qrPayload: qrPayload,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final endParts = startTime.split(':');
    final endH = (int.tryParse(endParts.isNotEmpty ? endParts[0] : '0') ?? 0) +
        durationHours;
    final endM = endParts.length > 1 ? endParts[1].padLeft(2, '0') : '00';
    final endTime = '${endH.toString().padLeft(2, '0')}:$endM';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A1F), Color(0xFF0B1510), Color(0xFF121810)],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty && !compact)
              SizedBox(
                height: 88,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PcNetworkImage(url: imageUrl!),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PLAYZON',
                          style: TextStyle(
                            color: Color(0xFF1A1000),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    if (statusLabel != null)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Text(
                          statusLabel!.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 14 : 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stadiumName,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 16 : 18,
                          ),
                        ),
                      ),
                      if (compact && statusLabel != null)
                        Text(
                          statusLabel!.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _meta('SANA', formatDateShort(date)),
                      ),
                      Expanded(
                        child: _meta('VAQT', '$startTime–$endTime'),
                      ),
                      Expanded(
                        child: _meta('DAVOM', '$durationHours soat'),
                      ),
                    ],
                  ),
                  if (bookingId != null || priceLabel != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (bookingId != null)
                          Text(
                            'BRON #$bookingId',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                        const Spacer(),
                        if (priceLabel != null)
                          Text(
                            priceLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (qrPayload != null && qrPayload!.isNotEmpty) ...[
              const SizedBox(height: 10),
              CustomPaint(
                painter: _TicketPerforationPainter(),
                child: const SizedBox(height: 18, width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: qrPayload!,
                        version: QrVersions.auto,
                        size: compact ? 72 : 96,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0B1510),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0B1510),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kirish QR',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Stadionda skaner qiling',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: qrPayload!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('QR nusxalandi')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Nusxa'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.gold.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}

class _TicketPerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const gap = 6.0;
    var x = 16.0;
    final y = size.height / 2;
    while (x < size.width - 16) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      x += gap;
    }
    final notch = Paint()..color = AppColors.bg;
    canvas.drawCircle(Offset(0, y), 10, notch);
    canvas.drawCircle(Offset(size.width, y), 10, notch);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-screen success / QR ticket sheet.
Future<void> showBookingTicketSheet(
  BuildContext context, {
  required Widget ticket,
  String title = 'Ticket tayyor',
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.paddingOf(ctx).bottom + 16,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.edge,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.confirmation_number,
                        color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ticket,
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onAction?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF1A1000),
                    ),
                    child: Text(actionLabel ?? 'Yopish'),
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

/// Mini ticket for tournament match tap.
class MatchMiniTicket extends StatelessWidget {
  const MatchMiniTicket({super.key, required this.match, this.roundLabel});

  final TournamentMatch match;
  final String? roundLabel;

  @override
  Widget build(BuildContext context) {
    final done = match.status == 'finished';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A1F), Color(0xFF0B1510)],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: done ? 0.65 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, AppColors.goldDark],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (roundLabel ?? 'MATCH').toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF1A1000),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                done ? 'FT' : match.status.toUpperCase(),
                style: TextStyle(
                  color: done ? AppColors.gold : AppColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  match.team1Name ?? 'Bye',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${match.score1 ?? '·'}  :  ${match.score2 ?? '·'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  match.team2Name ?? '—',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
          if (match.stadiumName != null && match.stadiumName!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stadium_outlined,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  match.stadiumName!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
