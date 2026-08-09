import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../models/models.dart';
import 'booking_ticket.dart';

/// FIFA / broadcast-style knockout bracket with path highlight.
class TournamentBracketView extends StatefulWidget {
  const TournamentBracketView({
    super.key,
    required this.matches,
    this.maxTeams,
    this.onTeamTap,
  });

  final List<TournamentMatch> matches;
  final int? maxTeams;
  final ValueChanged<int>? onTeamTap;

  @override
  State<TournamentBracketView> createState() => _TournamentBracketViewState();
}

class _TournamentBracketViewState extends State<TournamentBracketView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  int? _focusTeamId;

  static const _cardH = 78.0;
  static const _gap = 14.0;
  static const _colW = 196.0;
  static const _connector = 26.0;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  List<_RoundCol> _buildRounds() {
    final map = <int, List<TournamentMatch>>{};
    for (final m in widget.matches) {
      map.putIfAbsent(m.round, () => []).add(m);
    }
    final cols = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final rounds = [
      for (final e in cols)
        _RoundCol(
          round: e.key,
          items: [...e.value]..sort((a, b) => a.id.compareTo(b.id)),
        ),
    ];

    final maxTeams = widget.maxTeams;
    if (rounds.isNotEmpty && maxTeams != null && maxTeams >= 2) {
      final need = math.max(1, (math.log(maxTeams) / math.ln2).ceil());
      while (rounds.length < need) {
        final prev = rounds.last;
        final n = math.max(1, (prev.items.length / 2).ceil());
        rounds.add(
          _RoundCol(
            round: prev.round + 1,
            items: List.generate(
              n,
              (i) => TournamentMatch(
                id: -((prev.round + 1) * 100 + i),
                round: prev.round + 1,
                status: 'scheduled',
                team1Name: 'TBD',
                team2Name: 'TBD',
              ),
            ),
          ),
        );
      }
    }
    return rounds;
  }

  String _label(int idx, int total) {
    final fromEnd = total - 1 - idx;
    return switch (fromEnd) {
      0 => 'FINAL',
      1 => '1/2',
      2 => '1/4',
      3 => '1/8',
      _ => 'R${idx + 1}',
    };
  }

  double _slotTop(int roundIdx, int matchIdx) {
    final spacing = (_cardH + _gap) * math.pow(2, roundIdx).toDouble();
    final offset = (spacing - _cardH) / 2;
    return offset + matchIdx * spacing;
  }

  Set<int> _pathTeamIds(int teamId) {
    final out = <int>{teamId};
    // Walk winners through matches that involve this team
    for (final m in widget.matches) {
      if (m.team1Id == teamId || m.team2Id == teamId) {
        if (m.winnerTeamId != null) out.add(m.winnerTeamId!);
        if (m.team1Id != null) out.add(m.team1Id!);
        if (m.team2Id != null) out.add(m.team2Id!);
      }
    }
    // Also include any ancestor/descendant via winner chain
    var changed = true;
    while (changed) {
      changed = false;
      for (final m in widget.matches) {
        final involves = (m.team1Id != null && out.contains(m.team1Id)) ||
            (m.team2Id != null && out.contains(m.team2Id)) ||
            (m.winnerTeamId != null && out.contains(m.winnerTeamId));
        if (!involves) continue;
        for (final id in [m.team1Id, m.team2Id, m.winnerTeamId]) {
          if (id != null && out.add(id)) changed = true;
        }
      }
    }
    return out;
  }

  void _openMatch(TournamentMatch m, String roundLabel) {
    if (m.id < 0) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(ctx).bottom + 16,
        ),
        child: Material(
          color: const Color(0xFF0D1711),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                MatchMiniTicket(match: m, roundLabel: roundLabel),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Yopish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'Setka hali yo‘q — turnir boshlangach chiqadi',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    final rounds = _buildRounds();
    final n0 = rounds.first.items.length;
    final colH = n0 * (_cardH + _gap) + 40;
    final width = rounds.length * (_colW + _connector) - _connector;
    final path = _focusTeamId == null ? null : _pathTeamIds(_focusTeamId!);

    final lines = <_Line>[];
    for (var r = 0; r < rounds.length - 1; r++) {
      final cur = rounds[r].items;
      final next = rounds[r + 1].items;
      for (var i = 0; i < next.length; i++) {
        final a = i * 2;
        final b = i * 2 + 1;
        if (a >= cur.length) continue;
        final xLeft = (r + 1) * (_colW + _connector) - _connector;
        final xRight = (r + 1) * (_colW + _connector);
        final yA = _slotTop(r, a) + _cardH / 2;
        final yB = b < cur.length ? _slotTop(r, b) + _cardH / 2 : yA;
        final yMid = _slotTop(r + 1, i) + _cardH / 2;
        final xMid = xLeft + _connector / 2;
        lines.add(_Line(xLeft, yA, xMid, yA));
        if (b < cur.length) {
          lines.add(_Line(xLeft, yB, xMid, yB));
          lines.add(_Line(xMid, yA, xMid, yB));
        }
        lines.add(_Line(xMid, yMid, xRight, yMid));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_focusTeamId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Jamoa yo‘li yoritildi',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _focusTeamId = null),
                  child: const Text('Tozalash'),
                ),
              ],
            ),
          ),
        SizedBox(
          height: colH + 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              width: width,
              height: colH + 48,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 36,
                    width: width + _connector,
                    height: colH,
                    child: CustomPaint(
                      painter: _BracketLinesPainter(
                        lines: lines,
                        color: AppColors.lime.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  for (var rIdx = 0; rIdx < rounds.length; rIdx++)
                    Positioned(
                      left: rIdx * (_colW + _connector),
                      top: 0,
                      width: _colW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RoundHeader(
                            label: _label(rIdx, rounds.length),
                            isFinal: rIdx == rounds.length - 1,
                            glow: _glow,
                          ),
                          SizedBox(
                            height: colH,
                            child: Stack(
                              children: [
                                for (var mIdx = 0;
                                    mIdx < rounds[rIdx].items.length;
                                    mIdx++)
                                  Positioned(
                                    top: _slotTop(rIdx, mIdx),
                                    left: 0,
                                    right: 0,
                                    height: _cardH,
                                    child: _MatchNode(
                                      m: rounds[rIdx].items[mIdx],
                                      isFinal: rIdx == rounds.length - 1,
                                      glow: _glow,
                                      dim: path != null &&
                                          !_matchTouchesPath(
                                            rounds[rIdx].items[mIdx],
                                            path,
                                          ),
                                      highlight: path != null &&
                                          _matchTouchesPath(
                                            rounds[rIdx].items[mIdx],
                                            path,
                                          ),
                                      onTap: () => _openMatch(
                                        rounds[rIdx].items[mIdx],
                                        _label(rIdx, rounds.length),
                                      ),
                                      onTeam: (id) {
                                        setState(() => _focusTeamId = id);
                                        widget.onTeamTap?.call(id);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _matchTouchesPath(TournamentMatch m, Set<int> path) {
    return (m.team1Id != null && path.contains(m.team1Id)) ||
        (m.team2Id != null && path.contains(m.team2Id)) ||
        (m.winnerTeamId != null && path.contains(m.winnerTeamId));
  }
}

class _RoundCol {
  _RoundCol({required this.round, required this.items});
  final int round;
  final List<TournamentMatch> items;
}

class _Line {
  _Line(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
}

class _BracketLinesPainter extends CustomPainter {
  _BracketLinesPainter({required this.lines, required this.color});
  final List<_Line> lines;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final l in lines) {
      canvas.drawLine(Offset(l.x1, l.y1), Offset(l.x2, l.y2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _BracketLinesPainter old) =>
      old.lines != lines || old.color != color;
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({
    required this.label,
    required this.isFinal,
    required this.glow,
  });

  final String label;
  final bool isFinal;
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (_, __) {
        final pulse = isFinal ? glow.value : 0.0;
        return Container(
          height: 32,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: isFinal
                  ? const [AppColors.lime, Color(0xFF22C55E)]
                  : const [Color(0xFF163528), Color(0xFF0F1F18)],
            ),
            boxShadow: isFinal
                ? [
                    BoxShadow(
                      color: AppColors.lime
                          .withValues(alpha: 0.25 + pulse * 0.35),
                      blurRadius: 10 + pulse * 12,
                    ),
                  ]
                : null,
            border: Border.all(
              color: isFinal
                  ? AppColors.lime.withValues(alpha: 0.8)
                  : AppColors.edge,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: isFinal ? 2 : 1.2,
              fontSize: isFinal ? 13 : 11,
              color: isFinal ? const Color(0xFF052E12) : AppColors.ink,
            ),
          ),
        );
      },
    );
  }
}

class _MatchNode extends StatelessWidget {
  const _MatchNode({
    required this.m,
    required this.onTap,
    required this.onTeam,
    required this.glow,
    this.isFinal = false,
    this.dim = false,
    this.highlight = false,
  });

  final TournamentMatch m;
  final VoidCallback onTap;
  final ValueChanged<int> onTeam;
  final Animation<double> glow;
  final bool isFinal;
  final bool dim;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final live = m.status == 'scheduled' &&
        m.team1Id != null &&
        m.team2Id != null &&
        !m.isPlayed;
    final opacity = dim ? 0.42 : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedBuilder(
            animation: glow,
            builder: (_, __) {
              final pulse = (live || isFinal) ? glow.value : 0.0;
              return Ink(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D1711), Color(0xFF07110B)],
                  ),
                  border: Border.all(
                    color: highlight || isFinal
                        ? AppColors.lime.withValues(alpha: 0.75)
                        : live
                            ? AppColors.lime.withValues(alpha: 0.45)
                            : AppColors.edge,
                    width: highlight || isFinal ? 1.5 : 1,
                  ),
                  boxShadow: [
                    if (highlight || isFinal || live)
                      BoxShadow(
                        color: AppColors.lime
                            .withValues(alpha: 0.12 + pulse * 0.18),
                        blurRadius: 12 + pulse * 8,
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    if (live)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.lime
                                        .withValues(alpha: 0.5 + pulse * 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: AppColors.lime
                                    .withValues(alpha: 0.85 + pulse * 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (live) const SizedBox(height: 4),
                    Expanded(
                      child: _TeamRow(
                        name: m.team1Name ?? (m.id < 0 ? 'TBD' : 'Bye'),
                        score: m.score1,
                        winner: m.isPlayed && m.winnerTeamId != null
                            ? m.winnerTeamId == m.team1Id
                            : m.isPlayed &&
                                (m.score1 ?? 0) > (m.score2 ?? 0),
                        onTap: m.team1Id == null
                            ? null
                            : () => onTeam(m.team1Id!),
                      ),
                    ),
                    Divider(
                      height: 8,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    Expanded(
                      child: _TeamRow(
                        name: m.team2Name ?? (m.id < 0 ? 'TBD' : '—'),
                        score: m.score2,
                        winner: m.isPlayed && m.winnerTeamId != null
                            ? m.winnerTeamId == m.team2Id
                            : m.isPlayed &&
                                (m.score2 ?? 0) > (m.score1 ?? 0),
                        onTap: m.team2Id == null
                            ? null
                            : () => onTeam(m.team2Id!),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.name,
    required this.score,
    required this.winner,
    this.onTap,
  });

  final String name;
  final int? score;
  final bool winner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: winner ? FontWeight.w800 : FontWeight.w600,
              color: winner
                  ? AppColors.lime
                  : AppColors.ink.withValues(alpha: winner ? 1 : 0.88),
            ),
          ),
        ),
        Text(
          score == null ? '·' : '$score',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: winner ? AppColors.lime : AppColors.muted,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
