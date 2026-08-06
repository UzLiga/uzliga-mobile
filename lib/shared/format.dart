import 'package:intl/intl.dart';

String formatPrice(int amount) {
  final f = NumberFormat('#,###', 'uz');
  return '${f.format(amount).replaceAll(',', ' ')} so‘m';
}

String formatDateShort(String isoDate) {
  try {
    final d = DateTime.parse(isoDate);
    return DateFormat('d MMM', 'en').format(d);
  } catch (_) {
    return isoDate;
  }
}

String greetingForNow() {
  final h = DateTime.now().hour;
  if (h < 6) return 'Xayrli tun';
  if (h < 12) return 'Xayrli tong';
  if (h < 18) return 'Xayrli kun';
  return 'Xayrli kech';
}

String normalizePhone(String raw) {
  var p = raw.trim().replaceAll(' ', '');
  if (p.startsWith('998') && !p.startsWith('+')) p = '+$p';
  if (p.startsWith('9') && p.length == 9) p = '+998$p';
  if (p.startsWith('0') && p.length == 10) p = '+998${p.substring(1)}';
  if (!p.startsWith('+') && p.length >= 9) p = '+998$p';
  return p;
}

String bookingStatusLabel(String status) {
  switch (status) {
    case 'pending_payment':
      return 'To‘lov kutilmoqda';
    case 'confirmed':
      return 'Tasdiqlangan';
    case 'cancelled':
      return 'Bekor qilingan';
    default:
      return status;
  }
}
