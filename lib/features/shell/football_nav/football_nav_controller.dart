import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coordinates cinematic kick → fly → tab change without blocking navigation.
enum FootballNavPhase { idle, kick, fly, receive }

class FootballNavTransition {
  const FootballNavTransition({
    required this.id,
    required this.from,
    required this.to,
    required this.phase,
    required this.reverse,
  });

  final int id;
  final int from;
  final int to;
  final FootballNavPhase phase;
  final bool reverse;

  FootballNavTransition copyWith({FootballNavPhase? phase}) =>
      FootballNavTransition(
        id: id,
        from: from,
        to: to,
        phase: phase ?? this.phase,
        reverse: reverse,
      );
}

class FootballNavController extends Notifier<FootballNavTransition?> {
  int _seq = 0;

  @override
  FootballNavTransition? build() => null;

  /// Fire-and-forget cinematic nav. [go] is called early so UX stays snappy.
  Future<void> runTo({
    required int from,
    required int to,
    required void Function() go,
    required bool reduceMotion,
  }) async {
    if (from == to) {
      go();
      return;
    }
    if (reduceMotion) {
      go();
      return;
    }

    final id = ++_seq;
    final reverse = to == 0 && from != 0;
    state = FootballNavTransition(
      id: id,
      from: from,
      to: to,
      phase: reverse ? FootballNavPhase.fly : FootballNavPhase.kick,
      reverse: reverse,
    );

    if (!reverse) {
      // Oyoq to‘pga tegib ko‘rinsin — biroz ushlab, keyin past uchish
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (state?.id != id) return;
      state = state?.copyWith(phase: FootballNavPhase.fly);
    }

    await Future<void>.delayed(
      Duration(milliseconds: reverse ? 50 : 80),
    );
    if (state?.id != id && state != null) {
      // Another transition started; still navigate for this tap.
    }
    go();

    if (reverse) {
      if (state?.id == id) {
        state = state?.copyWith(phase: FootballNavPhase.receive);
      }
      await Future<void>.delayed(const Duration(milliseconds: 420));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    if (state?.id == id) state = null;
  }
}

final footballNavProvider =
    NotifierProvider<FootballNavController, FootballNavTransition?>(
  FootballNavController.new,
);

/// Trajectory helpers for flying ball (normalized 0..1 within overlay).
({double x, double y}) trajectoryFor({
  required int from,
  required int to,
  required double t,
  required bool reverse,
}) {
  double tabX(int i) => 0.125 + i * 0.25;
  // Oyoq yonidan (pastdan) → nav tugmasi — yuqori uchish yo‘q.
  final start = reverse
      ? (x: tabX(from), y: 0.90)
      : (x: 0.72, y: 0.62);
  final end = reverse
      ? (x: 0.72, y: 0.62)
      : (x: tabX(to), y: 0.90);

  // Past, yassi yo‘l — to‘p tepaga sakramaydi, nav bo‘ylab sirpanadi.
  final peakY = reverse
      ? ((start.y + end.y) / 2 - 0.04)
      : ((start.y + end.y) / 2 - 0.05);
  final peakX = (start.x + end.x) / 2 +
      ((reverse ? from : to) == 2
          ? 0.04
          : (reverse ? from : to) == 1
              ? -0.03
              : 0.0);

  final u = _easeOutCubic(t.clamp(0.0, 1.0));
  final x =
      (1 - u) * (1 - u) * start.x + 2 * (1 - u) * u * peakX + u * u * end.x;
  // Start pastroq (oyoq yonidan), arc juda past.
  final y0 = reverse ? start.y : 0.62;
  final y1 = end.y;
  final y =
      (1 - u) * (1 - u) * y0 + 2 * (1 - u) * u * peakY.clamp(0.55, 0.88) + u * u * y1;
  return (x: x, y: y);
}

double _easeOutCubic(double t) => 1 - (1 - t) * (1 - t) * (1 - t);

String footballTabLabel(int i) => switch (i) {
      0 => 'Asosiy',
      1 => 'O‘yinlar',
      2 => 'Lavhalar',
      3 => 'Profil',
      _ => 'Tab',
    };
