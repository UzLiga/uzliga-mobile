import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/models.dart';

class StandingRow {
  StandingRow({
    required this.teamName,
    this.played = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.gf = 0,
    this.ga = 0,
  });

  final String teamName;
  int played;
  int wins;
  int draws;
  int losses;
  int gf;
  int ga;

  int get gd => gf - ga;
  int get pts => wins * 3 + draws;
}

/// Knockout/liga matchlardan oddiy jadval (O‘Y W D L GF GA GD PTS).
List<StandingRow> computeStandings(List<TournamentMatch> matches) {
  final map = <String, StandingRow>{};

  StandingRow slot(String? name) {
    final n = (name == null || name.isEmpty || name == 'Bye' || name == '—')
        ? null
        : name;
    if (n == null) return StandingRow(teamName: '');
    return map.putIfAbsent(n, () => StandingRow(teamName: n));
  }

  for (final m in matches) {
    final done = m.status == 'finished' ||
        m.status == 'played' ||
        (m.score1 != null && m.score2 != null);
    if (!done) continue;
    final a = slot(m.team1Name);
    final b = slot(m.team2Name);
    if (a.teamName.isEmpty || b.teamName.isEmpty) continue;
    final s1 = m.score1 ?? 0;
    final s2 = m.score2 ?? 0;
    a.played++;
    b.played++;
    a.gf += s1;
    a.ga += s2;
    b.gf += s2;
    b.ga += s1;
    if (s1 > s2) {
      a.wins++;
      b.losses++;
    } else if (s2 > s1) {
      b.wins++;
      a.losses++;
    } else {
      a.draws++;
      b.draws++;
    }
  }

  final rows = map.values.toList()
    ..sort((x, y) {
      final p = y.pts.compareTo(x.pts);
      if (p != 0) return p;
      final g = y.gd.compareTo(x.gd);
      if (g != 0) return g;
      return y.gf.compareTo(x.gf);
    });
  return rows;
}

class LeagueTableView extends StatelessWidget {
  const LeagueTableView({super.key, required this.matches});

  final List<TournamentMatch> matches;

  @override
  Widget build(BuildContext context) {
    final rows = computeStandings(matches);
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.edge),
          color: AppColors.surface2,
        ),
        child: const Text(
          'Jadval hali yo‘q — o‘yin natijalari chiqgach to‘ldiriladi',
          style: TextStyle(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A1F), Color(0xFF0B1510)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppColors.gold.withValues(alpha: 0.15),
            child: const Row(
              children: [
                SizedBox(width: 28, child: Text('#', style: _h)),
                Expanded(child: Text('JAMOA', style: _h)),
                SizedBox(width: 28, child: Text('O', style: _h, textAlign: TextAlign.center)),
                SizedBox(width: 28, child: Text('W', style: _h, textAlign: TextAlign.center)),
                SizedBox(width: 28, child: Text('D', style: _h, textAlign: TextAlign.center)),
                SizedBox(width: 28, child: Text('L', style: _h, textAlign: TextAlign.center)),
                SizedBox(width: 36, child: Text('GD', style: _h, textAlign: TextAlign.center)),
                SizedBox(width: 36, child: Text('PTS', style: _h, textAlign: TextAlign.center)),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.edge.withValues(alpha: 0.5)),
                ),
                color: i == 0
                    ? AppColors.gold.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: i == 0 ? AppColors.gold : AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? AppColors.gold : AppColors.ink,
                      ),
                    ),
                  ),
                  _c('${rows[i].played}'),
                  _c('${rows[i].wins}'),
                  _c('${rows[i].draws}'),
                  _c('${rows[i].losses}'),
                  _c('${rows[i].gd >= 0 ? '+' : ''}${rows[i].gd}'),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${rows[i].pts}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _h = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    color: AppColors.gold,
    letterSpacing: 0.4,
  );

  Widget _c(String v) => SizedBox(
        width: 28,
        child: Text(
          v,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
}
