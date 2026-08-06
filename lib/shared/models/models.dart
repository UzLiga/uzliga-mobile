class PageResult<T> {
  const PageResult({required this.items, required this.total});

  final List<T> items;
  final int total;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = (json['items'] as List? ?? const []);
    return PageResult(
      items: raw
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? raw.length,
    );
  }
}

class UserBrief {
  const UserBrief({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.position,
    this.rating = 4.5,
  });

  final int id;
  final String fullName;
  final String? avatarUrl;
  final String? position;
  final double rating;

  factory UserBrief.fromJson(Map<String, dynamic> json) => UserBrief(
        id: json['id'] as int,
        fullName: json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        position: json['position'] as String?,
        rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      );
}

class User extends UserBrief {
  const User({
    required super.id,
    required super.fullName,
    super.avatarUrl,
    super.position,
    super.rating,
    this.phone,
    this.topBalance = 0,
    this.gamesPlayed = 0,
    this.goals = 0,
    this.assists = 0,
    this.isPremium = false,
    this.role = 'player',
    this.createdAt,
  });

  final String? phone;
  final int topBalance;
  final int gamesPlayed;
  final int goals;
  final int assists;
  final bool isPremium;
  final String role;
  final String? createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        fullName: json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        position: json['position'] as String?,
        rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
        phone: json['phone'] as String?,
        topBalance: (json['top_balance'] as num?)?.toInt() ?? 0,
        gamesPlayed: (json['games_played'] as num?)?.toInt() ?? 0,
        goals: (json['goals'] as num?)?.toInt() ?? 0,
        assists: (json['assists'] as num?)?.toInt() ?? 0,
        isPremium: json['is_premium'] as bool? ?? false,
        role: json['role'] as String? ?? 'player',
        createdAt: json['created_at'] as String?,
      );

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'Chempion' : parts.first;
  }
}

class StadiumBrief {
  const StadiumBrief({
    required this.id,
    required this.name,
    required this.district,
    required this.imageUrl,
    required this.pricePerHour,
  });

  final int id;
  final String name;
  final String district;
  final String imageUrl;
  final int pricePerHour;

  factory StadiumBrief.fromJson(Map<String, dynamic> json) => StadiumBrief(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        district: json['district'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        pricePerHour: (json['price_per_hour'] as num?)?.toInt() ?? 0,
      );
}

class Stadium {
  const Stadium({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.description,
    required this.pricePerHour,
    required this.rating,
    required this.reviewsCount,
    required this.imageUrl,
    required this.images,
    required this.surface,
    required this.size,
    required this.hasShower,
    required this.hasParking,
    required this.hasLighting,
    required this.openTime,
    required this.closeTime,
    this.lat,
    this.lng,
    this.phone,
  });

  final int id;
  final String name;
  final String district;
  final String address;
  final String description;
  final int pricePerHour;
  final double rating;
  final int reviewsCount;
  final String imageUrl;
  final List<String> images;
  final String surface;
  final String size;
  final bool hasShower;
  final bool hasParking;
  final bool hasLighting;
  final String openTime;
  final String closeTime;
  final double? lat;
  final double? lng;
  final String? phone;

  factory Stadium.fromJson(Map<String, dynamic> json) => Stadium(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        district: json['district'] as String? ?? '',
        address: json['address'] as String? ?? '',
        description: json['description'] as String? ?? '',
        pricePerHour: (json['price_per_hour'] as num?)?.toInt() ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
        imageUrl: json['image_url'] as String? ?? '',
        images: (json['images'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        surface: json['surface'] as String? ?? '',
        size: json['size'] as String? ?? '',
        hasShower: json['has_shower'] as bool? ?? false,
        hasParking: json['has_parking'] as bool? ?? false,
        hasLighting: json['has_lighting'] as bool? ?? false,
        openTime: json['open_time'] as String? ?? '08:00',
        closeTime: json['close_time'] as String? ?? '23:00',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        phone: json['phone'] as String?,
      );
}

class AvailabilitySlot {
  const AvailabilitySlot({required this.startTime, required this.available});

  final String startTime;
  final bool available;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      AvailabilitySlot(
        startTime: json['start_time'] as String? ?? '',
        available: json['available'] as bool? ?? false,
      );
}

class Availability {
  const Availability({required this.date, required this.slots});

  final String date;
  final List<AvailabilitySlot> slots;

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
        date: json['date'] as String? ?? '',
        slots: (json['slots'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => AvailabilitySlot.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class Booking {
  const Booking({
    required this.id,
    required this.stadium,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.durationHours,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final StadiumBrief stadium;
  final int userId;
  final String date;
  final String startTime;
  final int durationHours;
  final int totalPrice;
  final String status;
  final String createdAt;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as int,
        stadium: StadiumBrief.fromJson(
          Map<String, dynamic>.from(json['stadium'] as Map),
        ),
        userId: json['user_id'] as int,
        date: json['date'].toString(),
        startTime: json['start_time'].toString(),
        durationHours: (json['duration_hours'] as num?)?.toInt() ?? 1,
        totalPrice: (json['total_price'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        createdAt: json['created_at']?.toString() ?? '',
      );

  bool get isPending => status == 'pending_payment';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.captainId,
    required this.membersCount,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.createdAt,
    this.logoUrl,
    this.description,
    this.inviteCode,
  });

  final int id;
  final String name;
  final String? logoUrl;
  final String? description;
  final int captainId;
  final int membersCount;
  final int wins;
  final int losses;
  final int draws;
  final String createdAt;
  final String? inviteCode;

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        logoUrl: json['logo_url'] as String?,
        description: json['description'] as String?,
        captainId: json['captain_id'] as int,
        membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at']?.toString() ?? '',
        inviteCode: json['invite_code'] as String?,
      );
}

class TeamMember {
  const TeamMember({
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  final UserBrief user;
  final String role;
  final String joinedAt;

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        user: UserBrief.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
        role: json['role'] as String? ?? 'player',
        joinedAt: json['joined_at']?.toString() ?? '',
      );
}

class TeamDetail extends Team {
  const TeamDetail({
    required super.id,
    required super.name,
    required super.captainId,
    required super.membersCount,
    required super.wins,
    required super.losses,
    required super.draws,
    required super.createdAt,
    required this.members,
    super.logoUrl,
    super.description,
    super.inviteCode,
  });

  final List<TeamMember> members;

  factory TeamDetail.fromJson(Map<String, dynamic> json) {
    final base = Team.fromJson(json);
    return TeamDetail(
      id: base.id,
      name: base.name,
      logoUrl: base.logoUrl,
      description: base.description,
      captainId: base.captainId,
      membersCount: base.membersCount,
      wins: base.wins,
      losses: base.losses,
      draws: base.draws,
      createdAt: base.createdAt,
      inviteCode: base.inviteCode,
      members: (json['members'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => TeamMember.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class TeamInvitePreview {
  const TeamInvitePreview({
    required this.teamId,
    required this.name,
    required this.membersCount,
    required this.inviteCode,
    this.logoUrl,
    this.captainName,
  });

  final int teamId;
  final String name;
  final String? logoUrl;
  final int membersCount;
  final String? captainName;
  final String inviteCode;

  factory TeamInvitePreview.fromJson(Map<String, dynamic> json) =>
      TeamInvitePreview(
        teamId: json['team_id'] as int,
        name: json['name'] as String? ?? '',
        logoUrl: json['logo_url'] as String?,
        membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
        captainName: json['captain_name'] as String?,
        inviteCode: json['invite_code'] as String? ?? '',
      );
}

class Game {
  const Game({
    required this.id,
    required this.stadium,
    required this.creator,
    required this.date,
    required this.startTime,
    required this.format,
    required this.maxPlayers,
    required this.playersCount,
    required this.status,
    required this.createdAt,
    this.teamId,
    this.pricePerPlayer,
    this.comment,
    this.homeScore = 0,
    this.awayScore = 0,
  });

  final int id;
  final StadiumBrief stadium;
  final UserBrief creator;
  final int? teamId;
  final String date;
  final String startTime;
  final String format;
  final int maxPlayers;
  final int playersCount;
  final int? pricePerPlayer;
  final String? comment;
  final String status;
  final int homeScore;
  final int awayScore;
  final String createdAt;

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] as int,
        stadium: StadiumBrief.fromJson(
          Map<String, dynamic>.from(json['stadium'] as Map),
        ),
        creator: UserBrief.fromJson(
          Map<String, dynamic>.from(json['creator'] as Map),
        ),
        teamId: json['team_id'] as int?,
        date: json['date'].toString(),
        startTime: json['start_time'].toString(),
        format: json['format'] as String? ?? '',
        maxPlayers: (json['max_players'] as num?)?.toInt() ?? 0,
        playersCount: (json['players_count'] as num?)?.toInt() ?? 0,
        pricePerPlayer: (json['price_per_player'] as num?)?.toInt(),
        comment: json['comment'] as String?,
        status: json['status'] as String? ?? '',
        homeScore: (json['home_score'] as num?)?.toInt() ?? 0,
        awayScore: (json['away_score'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at']?.toString() ?? '',
      );

  bool get isOpen => status == 'open';
}

class GameDetail extends Game {
  const GameDetail({
    required super.id,
    required super.stadium,
    required super.creator,
    required super.date,
    required super.startTime,
    required super.format,
    required super.maxPlayers,
    required super.playersCount,
    required super.status,
    required super.createdAt,
    required this.players,
    super.teamId,
    super.pricePerPlayer,
    super.comment,
    super.homeScore,
    super.awayScore,
  });

  final List<UserBrief> players;

  factory GameDetail.fromJson(Map<String, dynamic> json) {
    final base = Game.fromJson(json);
    return GameDetail(
      id: base.id,
      stadium: base.stadium,
      creator: base.creator,
      teamId: base.teamId,
      date: base.date,
      startTime: base.startTime,
      format: base.format,
      maxPlayers: base.maxPlayers,
      playersCount: base.playersCount,
      pricePerPlayer: base.pricePerPlayer,
      comment: base.comment,
      status: base.status,
      homeScore: base.homeScore,
      awayScore: base.awayScore,
      createdAt: base.createdAt,
      players: (json['players'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => UserBrief.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class MatchClip {
  MatchClip({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.bookingId,
    this.playbackUrl,
    this.posterUrl,
    this.caption,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.likedByMe = false,
    this.createdAt,
    this.user,
    this.stadiumName,
    this.matchDate,
    this.matchTime,
  });

  final int id;
  final int? bookingId;
  final int userId;
  final String mediaUrl;
  final String mediaType;
  final String? playbackUrl;
  final String? posterUrl;
  final String? caption;
  int likeCount;
  int commentCount;
  int viewCount;
  bool likedByMe;
  final String? createdAt;
  final UserBrief? user;
  final String? stadiumName;
  final String? matchDate;
  final String? matchTime;

  String get streamUrl =>
      (playbackUrl != null && playbackUrl!.isNotEmpty) ? playbackUrl! : mediaUrl;

  factory MatchClip.fromJson(Map<String, dynamic> json) => MatchClip(
        id: json['id'] as int,
        bookingId: (json['booking_id'] as num?)?.toInt(),
        userId: json['user_id'] as int,
        mediaUrl: json['media_url'] as String? ?? '',
        mediaType: json['media_type'] as String? ?? 'image',
        playbackUrl: json['playback_url'] as String?,
        posterUrl: json['poster_url'] as String?,
        caption: json['caption'] as String?,
        likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
        viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
        likedByMe: json['liked_by_me'] as bool? ?? false,
        createdAt: json['created_at'] as String?,
        user: json['user'] is Map
            ? UserBrief.fromJson(Map<String, dynamic>.from(json['user'] as Map))
            : null,
        stadiumName: json['stadium_name'] as String?,
        matchDate: json['match_date'] as String?,
        matchTime: json['match_time'] as String?,
      );
}

class ClipComment {
  const ClipComment({
    required this.id,
    required this.userId,
    required this.body,
    this.createdAt,
    this.user,
  });

  final int id;
  final int userId;
  final String body;
  final String? createdAt;
  final UserBrief? user;

  factory ClipComment.fromJson(Map<String, dynamic> json) => ClipComment(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        body: json['body'] as String? ?? '',
        createdAt: json['created_at'] as String?,
        user: json['user'] is Map
            ? UserBrief.fromJson(Map<String, dynamic>.from(json['user'] as Map))
            : null,
      );
}


class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.format,
    required this.maxTeams,
    required this.status,
    required this.creatorId,
    this.teamsCount = 0,
    this.level,
    this.stadiumName,
    this.winnerTeamName,
    this.startDate,
    this.description,
  });

  final int id;
  final String name;
  final String format;
  final int maxTeams;
  final String status;
  final int creatorId;
  final int teamsCount;
  final String? level;
  final String? stadiumName;
  final String? winnerTeamName;
  final String? startDate;
  final String? description;

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        format: json['format'] as String? ?? '7x7',
        maxTeams: (json['max_teams'] as num?)?.toInt() ?? 8,
        status: json['status'] as String? ?? 'open',
        creatorId: (json['creator_id'] as num?)?.toInt() ?? 0,
        teamsCount: (json['teams_count'] as num?)?.toInt() ?? 0,
        level: json['level'] as String?,
        stadiumName: json['stadium_name'] as String?,
        winnerTeamName: json['winner_team_name'] as String?,
        startDate: json['start_date']?.toString(),
        description: json['description'] as String?,
      );
}

class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.round,
    required this.status,
    this.team1Name,
    this.team2Name,
    this.score1,
    this.score2,
    this.winnerTeamId,
    this.stadiumName,
  });

  final int id;
  final int round;
  final String status;
  final String? team1Name;
  final String? team2Name;
  final int? score1;
  final int? score2;
  final int? winnerTeamId;
  final String? stadiumName;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) => TournamentMatch(
        id: json['id'] as int,
        round: (json['round'] as num?)?.toInt() ?? 1,
        status: json['status'] as String? ?? 'scheduled',
        team1Name: json['team1_name'] as String?,
        team2Name: json['team2_name'] as String?,
        score1: (json['score1'] as num?)?.toInt(),
        score2: (json['score2'] as num?)?.toInt(),
        winnerTeamId: (json['winner_team_id'] as num?)?.toInt(),
        stadiumName: json['stadium_name'] as String?,
      );
}

class TournamentDetail extends Tournament {
  const TournamentDetail({
    required super.id,
    required super.name,
    required super.format,
    required super.maxTeams,
    required super.status,
    required super.creatorId,
    super.teamsCount,
    super.level,
    super.stadiumName,
    super.winnerTeamName,
    super.startDate,
    super.description,
    this.matches = const [],
  });

  final List<TournamentMatch> matches;

  factory TournamentDetail.fromJson(Map<String, dynamic> json) => TournamentDetail(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        format: json['format'] as String? ?? '7x7',
        maxTeams: (json['max_teams'] as num?)?.toInt() ?? 8,
        status: json['status'] as String? ?? 'open',
        creatorId: (json['creator_id'] as num?)?.toInt() ?? 0,
        teamsCount: (json['teams_count'] as num?)?.toInt() ?? 0,
        level: json['level'] as String?,
        stadiumName: json['stadium_name'] as String?,
        winnerTeamName: json['winner_team_name'] as String?,
        startDate: json['start_date']?.toString(),
        description: json['description'] as String?,
        matches: ((json['matches'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => TournamentMatch.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}


class FreeAgentPost {
  const FreeAgentPost({
    required this.id,
    required this.user,
    required this.type,
    required this.comment,
    required this.status,
    this.position,
    this.date,
    this.time,
    this.locationText,
    this.phone,
    this.createdAt,
  });

  final int id;
  final UserBrief user;
  final String type;
  final String comment;
  final String status;
  final String? position;
  final String? date;
  final String? time;
  final String? locationText;
  final String? phone;
  final String? createdAt;

  factory FreeAgentPost.fromJson(Map<String, dynamic> json) => FreeAgentPost(
        id: json['id'] as int,
        user: UserBrief.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
        type: json['type'] as String? ?? 'want_to_play',
        comment: json['comment'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        position: json['position'] as String?,
        date: json['date']?.toString(),
        time: json['time']?.toString(),
        locationText: json['location_text'] as String?,
        phone: json['phone'] as String?,
        createdAt: json['created_at']?.toString(),
      );

  bool get needPlayer => type == 'need_player';
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.link,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? link;
  final String? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? 'system',
        isRead: json['is_read'] as bool? ?? false,
        link: json['link'] as String?,
        createdAt: json['created_at']?.toString(),
      );
}

class WalletInfo {
  const WalletInfo({
    required this.balance,
    required this.items,
    this.total = 0,
  });

  final int balance;
  final List<WalletTx> items;
  final int total;

  factory WalletInfo.fromJson(Map<String, dynamic> json) => WalletInfo(
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => WalletTx.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class WalletTx {
  const WalletTx({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    this.note,
    this.createdAt,
  });

  final int id;
  final int amount;
  final int balanceAfter;
  final String reason;
  final String? note;
  final String? createdAt;

  factory WalletTx.fromJson(Map<String, dynamic> json) => WalletTx(
        id: json['id'] as int,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        note: json['note'] as String?,
        createdAt: json['created_at']?.toString(),
      );
}
