import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/models.dart';

/// FIFA / Champions / DLS uslubidagi o‘yinchi kartasi.
class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.name,
    required this.overall,
    this.position,
    this.avatarUrl,
    this.isCaptain = false,
    this.compact = false,
    this.profile = false,
    this.onTap,
    this.pace,
    this.shooting,
    this.passing,
    this.dribbling,
    this.defending,
    this.stamina,
    this.showFullStatsOnTap = true,
  });

  factory PlayerCard.fromUser(
    UserBrief u, {
    bool isCaptain = false,
    bool compact = false,
    bool profile = false,
    VoidCallback? onTap,
    bool showFullStatsOnTap = true,
  }) {
    return PlayerCard(
      name: u.firstName.toUpperCase(),
      overall: u.overall,
      position: _pos(u.position),
      avatarUrl: u.avatarUrl,
      isCaptain: isCaptain,
      compact: compact,
      profile: profile,
      onTap: onTap,
      pace: u.pace,
      shooting: u.shooting,
      passing: u.passing,
      dribbling: u.dribbling,
      defending: u.defending,
      stamina: u.stamina,
      showFullStatsOnTap: showFullStatsOnTap,
    );
  }

  final String name;
  final int overall;
  final String? position;
  final String? avatarUrl;
  final bool isCaptain;
  final bool compact;
  final bool profile;
  final VoidCallback? onTap;
  final int? pace;
  final int? shooting;
  final int? passing;
  final int? dribbling;
  final int? defending;
  final int? stamina;
  final bool showFullStatsOnTap;

  static String normalizePos(String? p) => _pos(p);

  static String _pos(String? p) {
    if (p == null || p.isEmpty) return 'CM';
    final s = p.toUpperCase();
    if (s == 'GK' || s == 'CB' || s == 'LB' || s == 'RB' || s == 'CDM' ||
        s == 'CM' || s == 'CAM' || s == 'LW' || s == 'RW' || s == 'ST') {
      return s;
    }
    if (s.length <= 3 && RegExp(r'^[A-Z]+$').hasMatch(s)) return s;
    if (s.contains('DARVOZA') || s.contains('GK')) return 'GK';
    if (s.contains('HIMOY') || s.contains('DEF')) return 'CB';
    if (s.contains('YARIM')) return 'CM';
    if (s.contains('HUJUM') || s.contains('ST')) return 'ST';
    return s.length >= 2 ? s.substring(0, 2) : 'CM';
  }

  static String positionLabelUz(String? p) {
    final code = _pos(p);
    return switch (code) {
      'GK' => 'Darvozabon',
      'CB' => 'Markaziy himoyachi',
      'LB' => 'Chap himoyachi',
      'RB' => 'O‘ng himoyachi',
      'CDM' => 'Himoyaviy yarim',
      'CM' => 'Yarim himoyachi',
      'CAM' => 'Hujumkor yarim',
      'LW' => 'Chap qanot',
      'RW' => 'O‘ng qanot',
      'ST' => 'Hujumchi',
      _ => code,
    };
  }

  static String attrLabelUz(String code) => switch (code) {
        'PAC' => 'Tezlik',
        'SHO' => 'Zarba',
        'PAS' => 'Uzatma',
        'DRI' => 'Dribling',
        'DEF' => 'Himoya',
        'PHY' => 'Jismoniy',
        _ => code,
      };

  Color get _tier {
    if (overall >= 80) return const Color(0xFFE8B923);
    if (overall >= 70) return const Color(0xFF3B82F6);
    return const Color(0xFF94A3B8);
  }

  void _openStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1510),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
            const SizedBox(height: 16),
            Row(
              children: [
                PlayerCard(
                  name: name,
                  overall: overall,
                  position: position,
                  avatarUrl: avatarUrl,
                  isCaptain: isCaptain,
                  compact: true,
                  showFullStatsOnTap: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('${position ?? 'CM'} · OVR $overall',
                          style: TextStyle(
                              color: _tier, fontWeight: FontWeight.w700)),
                      if (onTap != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onTap!();
                          },
                          child: const Text('To‘liq profil →'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _StatsGrid(
              pace: pace ?? 65,
              shooting: shooting ?? 65,
              passing: passing ?? 65,
              dribbling: dribbling ?? 65,
              defending: defending ?? 65,
              stamina: stamina ?? 65,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = compact ? 76.0 : (profile ? 200.0 : 118.0);
    final h = compact ? 102.0 : (profile ? 288.0 : 162.0);
    final pac = pace ?? 65;
    final sho = shooting ?? 65;
    final pas = passing ?? 65;
    final dri = dribbling ?? 65;
    final def = defending ?? 65;
    final phy = stamina ?? 65;

    return GestureDetector(
      onTap: () {
        if (onTap != null && !showFullStatsOnTap) {
          onTap!();
          return;
        }
        if (showFullStatsOnTap) {
          _openStats(context);
        } else if (onTap != null) {
          onTap!();
        }
      },
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(profile ? 18 : 14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(_tier, const Color(0xFF0B1A2A), 0.15)!,
              const Color(0xFF0B1A2A),
              const Color(0xFF050D14),
            ],
            stops: const [0.0, 0.32, 1],
          ),
          border: Border.all(color: _tier, width: profile ? 2.4 : 2),
          boxShadow: [
            BoxShadow(
              color: _tier.withValues(alpha: profile ? 0.55 : 0.45),
              blurRadius: profile ? 22 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Profil FIFA: o‘yinchi rasmi butun karta fonida
            if (profile && avatarUrl != null && avatarUrl!.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    fadeInDuration: const Duration(milliseconds: 80),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (profile)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(profile ? 15 : 11),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16)),
                    gradient: profile
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.06),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 7 : (profile ? 12 : 9),
                compact ? 7 : (profile ? 12 : 9),
                compact ? 7 : (profile ? 12 : 9),
                6,
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$overall',
                            style: TextStyle(
                              fontSize: compact ? 17 : (profile ? 36 : 24),
                              fontWeight: FontWeight.w900,
                              color: _tier,
                              height: 1,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black54)
                              ],
                            ),
                          ),
                          Text(
                            position ?? 'CM',
                            style: TextStyle(
                              fontSize: compact ? 9 : (profile ? 14 : 11),
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          if (profile)
                            Text(
                              positionLabelUz(position),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      const Text('🇺🇿', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  if (profile)
                    const Spacer()
                  else
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _tier, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _tier.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: SizedBox(
                            width: compact ? 40 : 60,
                            height: compact ? 40 : 60,
                            child: avatarUrl != null && avatarUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: compact ? 80 : 120,
                                    fadeInDuration:
                                        const Duration(milliseconds: 60),
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, __) => Container(
                                      color: Colors.black45,
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.isNotEmpty ? name[0] : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: compact ? 14 : 20,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.black45,
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.isNotEmpty ? name[0] : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: compact ? 14 : 20,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.black45,
                                    alignment: Alignment.center,
                                    child: Text(
                                      name.isNotEmpty ? name[0] : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: compact ? 14 : 20,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 9 : (profile ? 14 : 11),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 6),
                    if (profile)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _mini('PAC', pac, uz: true),
                              _mini('SHO', sho, uz: true),
                              _mini('PAS', pas, uz: true),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _mini('DRI', dri, uz: true),
                              _mini('DEF', def, uz: true),
                              _mini('PHY', phy, uz: true),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _mini('PAC', pac),
                          _mini('SHO', sho),
                          _mini('PAS', pas),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            if (profile)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _tier, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 128,
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Text(name.isNotEmpty ? name[0] : '?'),
                            ),
                          )
                        : Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: Text(name.isNotEmpty ? name[0] : '?'),
                          ),
                  ),
                ),
              ),
            if (isCaptain)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('C',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF052E12))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String k, int v, {bool uz = false}) => Column(
        children: [
          Text('$v',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900, height: 1)),
          Text(uz ? attrLabelUz(k) : k,
              style: TextStyle(
                  fontSize: uz ? 6.5 : 7,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.2)),
        ],
      );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.pace,
    required this.shooting,
    required this.passing,
    required this.dribbling,
    required this.defending,
    required this.stamina,
  });

  final int pace, shooting, passing, dribbling, defending, stamina;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('PAC', pace),
      ('SHO', shooting),
      ('PAS', passing),
      ('DRI', dribbling),
      ('DEF', defending),
      ('PHY', stamina),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        for (final it in items)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.edge),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${it.$2}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                Text(it.$1,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Maydon bo‘yicha joylashuv (format 5/7/11).
class PitchFormation extends StatelessWidget {
  const PitchFormation({
    super.key,
    required this.members,
    required this.formatSize,
    this.captainId,
    this.onPlayerTap,
    this.emptySlotsHint = true,
  });

  /// O‘yin rosteridan — TeamMember wrapper.
  factory PitchFormation.fromUsers({
    Key? key,
    required List<UserBrief> players,
    required int formatSize,
    int? captainId,
    void Function(UserBrief user)? onPlayerTap,
  }) {
    return PitchFormation(
      key: key,
      members: [
        for (final u in players)
          TeamMember(user: u, role: 'player', joinedAt: ''),
      ],
      formatSize: formatSize,
      captainId: captainId,
      onPlayerTap: onPlayerTap,
    );
  }

  final List<TeamMember> members;
  final int formatSize;
  final int? captainId;
  final void Function(UserBrief user)? onPlayerTap;
  final bool emptySlotsHint;

  List<Offset> get _slots {
    switch (formatSize) {
      case 5:
        return const [
          Offset(0.5, 0.88),
          Offset(0.22, 0.62),
          Offset(0.78, 0.62),
          Offset(0.35, 0.32),
          Offset(0.65, 0.32),
        ];
      case 11:
        return const [
          Offset(0.5, 0.92),
          Offset(0.18, 0.72),
          Offset(0.38, 0.74),
          Offset(0.62, 0.74),
          Offset(0.82, 0.72),
          Offset(0.28, 0.48),
          Offset(0.5, 0.50),
          Offset(0.72, 0.48),
          Offset(0.22, 0.22),
          Offset(0.5, 0.18),
          Offset(0.78, 0.22),
        ];
      default:
        // 7v7: GK, LB, CB, RB, LM, RM, ST
        return const [
          Offset(0.5, 0.90),
          Offset(0.22, 0.68),
          Offset(0.5, 0.70),
          Offset(0.78, 0.68),
          Offset(0.28, 0.38),
          Offset(0.72, 0.38),
          Offset(0.5, 0.16),
        ];
    }
  }

  /// Pozitsiya → slot index (GK darvozada, ST hujumda).
  static int slotIndexFor(String? position, int formatSize) {
    final p = PlayerCard.normalizePos(position);
    if (formatSize == 5) {
      return switch (p) {
        'GK' => 0,
        'LB' || 'CB' || 'CDM' => 1,
        'RB' || 'DEF' => 2,
        'LW' || 'CM' || 'CAM' => 3,
        _ => 4, // ST / RW
      };
    }
    if (formatSize == 11) {
      return switch (p) {
        'GK' => 0,
        'LB' => 1,
        'CB' => 2,
        'CDM' => 3,
        'RB' => 4,
        'CM' => 5,
        'CAM' => 6,
        'RM' || 'RW' => 7,
        'LW' => 8,
        'ST' => 9,
        _ => 10,
      };
    }
    // 7v7
    return switch (p) {
      'GK' => 0,
      'LB' => 1,
      'CB' || 'CDM' => 2,
      'RB' => 3,
      'CM' || 'CAM' || 'LW' => 4,
      'RW' || 'RM' => 5,
      _ => 6, // ST
    };
  }

  /// A'zolarni pozitsiya bo‘yicha slotlarga joylashtirish (to‘qnashuvsiz).
  List<({TeamMember member, int slot})> _placed(List<Offset> slots) {
    final used = <int>{};
    final out = <({TeamMember member, int slot})>[];
    final pending = members.take(slots.length).toList();

    for (final m in pending) {
      var slot = slotIndexFor(m.user.position, formatSize).clamp(0, slots.length - 1);
      if (used.contains(slot)) {
        // Eng yaqin bo‘sh slot
        var found = false;
        for (var d = 1; d < slots.length && !found; d++) {
          for (final cand in [slot - d, slot + d]) {
            if (cand >= 0 && cand < slots.length && !used.contains(cand)) {
              slot = cand;
              found = true;
              break;
            }
          }
        }
        if (!found) {
          for (var i = 0; i < slots.length; i++) {
            if (!used.contains(i)) {
              slot = i;
              break;
            }
          }
        }
      }
      used.add(slot);
      out.add((member: m, slot: slot));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final placed = _placed(slots);
    final usedSlots = placed.map((e) => e.slot).toSet();
    final emptyCount = (slots.length - placed.length).clamp(0, slots.length);
    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF166534), Color(0xFF052E16), Color(0xFF03140A)],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _PitchPainter()),
                Positioned(
                  left: 14,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatSize == 11
                          ? '11v11 · 4-3-3'
                          : formatSize == 5
                              ? '5v5'
                              : '7v7',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                          fontSize: 11),
                    ),
                  ),
                ),
                if (emptySlotsHint && emptyCount > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Text(
                      '+$emptyCount joy',
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                for (final p in placed)
                  Positioned(
                    left: slots[p.slot].dx * c.maxWidth - 38,
                    top: slots[p.slot].dy * c.maxHeight - 50,
                    child: PlayerCard.fromUser(
                      p.member.user,
                      isCaptain: p.member.user.id == captainId ||
                          p.member.role == 'captain',
                      compact: true,
                      showFullStatsOnTap: true,
                      onTap: onPlayerTap == null
                          ? null
                          : () => onPlayerTap!(p.member.user),
                    ),
                  ),
                if (emptySlotsHint)
                  for (var i = 0; i < slots.length; i++)
                    if (!usedSlots.contains(i))
                      Positioned(
                        left: slots[i].dx * c.maxWidth - 18,
                        top: slots[i].dy * c.maxHeight - 18,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1.5,
                            ),
                            color: Colors.black26,
                          ),
                          child: Icon(Icons.add,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(r, p);
    canvas.drawLine(
      Offset(12, size.height / 2),
      Offset(size.width - 12, size.height / 2),
      p,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 30, p);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2, 38),
          width: size.width * 0.48,
          height: 52),
      p,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height - 38),
          width: size.width * 0.48,
          height: 52),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
