/// Local career / RPG helper (mirrors backend tiers).
class CareerInfo {
  const CareerInfo({
    required this.level,
    required this.key,
    required this.title,
    required this.discountPercent,
    required this.shopHint,
    required this.progress,
    required this.gamesToNext,
    required this.gamesPlayed,
  });

  final int level;
  final String key;
  final String title;
  final int discountPercent;
  final String shopHint;
  final double progress;
  final int gamesToNext;
  final int gamesPlayed;

  static const _tiers = <(int, String, String, int, String)>[
    (0, 'rookie', 'Yangi o‘yinchi', 0, 'Keyingi daraja: 5 o‘yin'),
    (5, 'mahalla', 'Mahalla afsonasi', 5, 'Sport do‘konlarida 5% chegirma'),
    (15, 'semi', 'Yarim-professional', 10, 'Sport do‘konlarida 10% chegirma'),
    (30, 'star', 'Yulduz', 15, 'Sport do‘konlarida 15% chegirma'),
    (50, 'legend', 'Legenda', 20, 'Sport do‘konlarida 20% chegirma'),
  ];

  factory CareerInfo.fromGames(int gamesPlayed) {
    final g = gamesPlayed < 0 ? 0 : gamesPlayed;
    var idx = 0;
    for (var i = 0; i < _tiers.length; i++) {
      if (g >= _tiers[i].$1) idx = i;
    }
    final t = _tiers[idx];
    final next = idx + 1 < _tiers.length ? _tiers[idx + 1] : null;
    double progress;
    int toNext;
    if (next == null) {
      progress = 1;
      toNext = 0;
    } else {
      final span = (next.$1 - t.$1).clamp(1, 9999);
      progress = ((g - t.$1) / span).clamp(0.0, 1.0);
      toNext = (next.$1 - g).clamp(0, 9999);
    }
    return CareerInfo(
      level: idx + 1,
      key: t.$2,
      title: t.$3,
      discountPercent: t.$4,
      shopHint: t.$5,
      progress: progress,
      gamesToNext: toNext,
      gamesPlayed: g,
    );
  }

  factory CareerInfo.fromUserJson(Map<String, dynamic> json, int gamesPlayed) {
    if (json['career_title'] is String) {
      return CareerInfo(
        level: (json['career_level'] as num?)?.toInt() ?? 1,
        key: json['career_key'] as String? ?? 'rookie',
        title: json['career_title'] as String,
        discountPercent: (json['career_discount_percent'] as num?)?.toInt() ?? 0,
        shopHint: json['career_shop_hint'] as String? ?? '',
        progress: (json['career_progress'] as num?)?.toDouble() ?? 0,
        gamesToNext: (json['career_games_to_next'] as num?)?.toInt() ?? 0,
        gamesPlayed: gamesPlayed,
      );
    }
    return CareerInfo.fromGames(gamesPlayed);
  }
}
