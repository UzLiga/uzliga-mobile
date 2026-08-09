import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../profile/profile_screen.dart';
import 'my_reels_screen.dart';

/// Premium football broadcast-style clip composer (Match Moment).
class ClipComposerScreen extends ConsumerStatefulWidget {
  const ClipComposerScreen({super.key});

  @override
  ConsumerState<ClipComposerScreen> createState() => _ClipComposerScreenState();
}

class _Moment {
  const _Moment(this.id, this.emoji, this.label, this.tag);
  final String id;
  final String emoji;
  final String label;
  final String tag;
}

class _Track {
  const _Track(this.id, this.title, this.category);
  final String id;
  final String title;
  final String category;
}

class _ClipComposerScreenState extends ConsumerState<ClipComposerScreen>
    with SingleTickerProviderStateMixin {
  static const _moments = [
    _Moment('goal', '⚽', 'GOAL', 'goal'),
    _Moment('skill', '🔥', 'SKILL', 'skill'),
    _Moment('save', '🧤', 'SAVE', 'save'),
    _Moment('assist', '🎯', 'ASSIST', 'assist'),
    _Moment('celebration', '🏆', 'CELEBRATION', 'celebration'),
    _Moment('reaction', '😱', 'REACTION', 'reaction'),
    _Moment('red', '🟥', 'RED CARD', 'redcard'),
    _Moment('yellow', '🟨', 'YELLOW', 'yellowcard'),
    _Moment('best', '💥', 'BEST MOMENT', 'best'),
  ];

  static const _tracks = [
    _Track('hype1', 'Stadium Energy', '🔥 Hype'),
    _Track('hype2', 'Crowd Roar', '🔥 Hype'),
    _Track('stad1', 'Floodlights', '🏟️ Stadium'),
    _Track('stad2', 'Matchday Pulse', '🏟️ Stadium'),
    _Track('cine1', 'Final Whistle', '🎬 Cinematic'),
    _Track('cele1', 'Trophy Lift', '🎉 Celebration'),
  ];

  XFile? _file;
  VideoPlayerController? _player;
  String? _momentId;
  String? _trackId;
  final _caption = TextEditingController();
  int _step = 0; // 0 pick → 1 moment → 2 editor → 3 caption → 4 publish
  bool _uploading = false;
  double _progress = 0;
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  String? _overlay; // scoreboard | goal | match | sticker | effect
  String _customText = 'GOAL!';
  String? _sticker;
  late final AnimationController _lights;

  @override
  void initState() {
    super.initState();
    _lights = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _lights.dispose();
    _caption.dispose();
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  void _onTick() {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    if (p.value.position >= _trimEnd && _trimEnd > _trimStart) {
      p.seekTo(_trimStart);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (file == null) return;
    await _player?.dispose();
    final ctrl = VideoPlayerController.file(File(file.path));
    await ctrl.initialize();
    ctrl.setLooping(false);
    await ctrl.play();
    ctrl.addListener(_onTick);
    setState(() {
      _file = file;
      _player = ctrl;
      _trimStart = Duration.zero;
      _trimEnd = ctrl.value.duration;
      _step = 1;
    });
    HapticFeedback.mediumImpact();
  }

  String get _builtCaption {
    _Moment? moment;
    for (final m in _moments) {
      if (m.id == _momentId) moment = m;
    }
    _Track? track;
    for (final t in _tracks) {
      if (t.id == _trackId) track = t;
    }
    final buf = StringBuffer();
    final text = _caption.text.trim();
    if (text.isNotEmpty) buf.writeln(text);
    if (moment != null) {
      buf.writeln('${moment.emoji} ${moment.label}');
      buf.writeln('#${moment.tag} #football #matchday');
    } else {
      buf.writeln('#football #matchday');
    }
    if (_overlay == 'goal' || _customText.trim().isNotEmpty && _overlay == 'match') {
      buf.writeln(_customText.trim());
    }
    if (_sticker != null) buf.writeln(_sticker);
    if (track != null) buf.writeln('🎵 ${track.title}');
    final sec = (_trimEnd - _trimStart).inSeconds;
    if (sec > 0 && sec < (_player?.value.duration.inSeconds ?? 999)) {
      buf.writeln('✂️ ${sec}s highlight');
    }
    return buf.toString().trim();
  }

  Future<void> _publish() async {
    if (_file == null || _uploading) return;
      setState(() {
      _uploading = true;
      _progress = 0.08;
      _step = 4;
    });
    // Smooth fake progress while network upload runs
    var tick = 0;
    final timer = Stream.periodic(const Duration(milliseconds: 180), (_) {
      tick++;
      if (!_uploading || !mounted) return;
      setState(() {
        _progress = (_progress + (0.04 + (tick % 3) * 0.01)).clamp(0.0, 0.88);
      });
    }).listen((_) {});

    try {
      await ref.read(apiClientProvider).uploadClip(
            filePath: _file!.path,
            fileName: _file!.name,
            caption: _builtCaption,
          );
      timer.cancel();
      if (!mounted) return;
      setState(() => _progress = 1);
      HapticFeedback.heavyImpact();
      ref.invalidate(manageClipsProvider);
      ref.invalidate(myClipsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ MATCH MOMENT READY')),
      );
      context.pop(true);
    } catch (e) {
      timer.cancel();
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _step = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: pcAppBar(
        context,
        title: switch (_step) {
          0 => 'Match Moment',
          1 => 'Nima bo‘ldi?',
          2 => 'Editor',
          3 => 'Caption',
          _ => 'Yuklash',
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _StadiumBackdrop(lights: _lights),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: switch (_step) {
                0 => _PickStep(key: const ValueKey(0), onPick: _pick),
                1 => _MomentStep(
                    key: const ValueKey(1),
                    player: _player,
                    moments: _moments,
                    selected: _momentId,
                    onSelect: (id) => setState(() => _momentId = id),
                    onNext: () {
                      if (_momentId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Moment turini tanlang')),
                        );
                        return;
                      }
                      setState(() => _step = 2);
                    },
                    onBack: () => setState(() => _step = 0),
                  ),
                2 => _EditorStep(
                    key: const ValueKey(2),
                    player: _player,
                    trimStart: _trimStart,
                    trimEnd: _trimEnd,
                    overlay: _overlay,
                    customText: _customText,
                    sticker: _sticker,
                    onTrim: (a, b) => setState(() {
                      _trimStart = a;
                      _trimEnd = b;
                    }),
                    onOverlay: (v) => setState(() => _overlay = v),
                    onText: (v) => setState(() => _customText = v),
                    onSticker: (v) => setState(() => _sticker = v),
                    onBack: () => setState(() => _step = 1),
                    onNext: () {
                      _player?.seekTo(_trimStart);
                      setState(() => _step = 3);
                    },
                  ),
                3 => _CaptionStep(
                    key: const ValueKey(3),
                    player: _player,
                    caption: _caption,
                    tracks: _tracks,
                    trackId: _trackId,
                    overlay: _overlay,
                    customText: _customText,
                    sticker: _sticker,
                    onTrack: (id) => setState(() => _trackId = id),
                    onBack: () => setState(() => _step = 2),
                    onPublish: _publish,
                  ),
                _ => _UploadStep(
                    key: const ValueKey(4),
                    progress: _progress,
                    done: _progress >= 1,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StadiumBackdrop extends StatelessWidget {
  const _StadiumBackdrop({required this.lights});
  final Animation<double> lights;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: lights,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(lights.value);
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF07110B),
                      Color(0xFF050807),
                      Color(0xFF0A120D),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: 0.35 * t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.85),
                      radius: 1.1,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: 0.2 * t,
                child: CustomPaint(painter: _PitchLinesPainter()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PitchLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.55, size.width * 0.76,
          size.height * 0.38),
      const Radius.circular(12),
    );
    canvas.drawRRect(r, p);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.74),
      size.width * 0.12,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PickStep extends StatelessWidget {
  const _PickStep({super.key, required this.onPick});
  final Future<void> Function(ImageSource) onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lime.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.lime.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.2),
                  blurRadius: 28,
                ),
              ],
            ),
            child: const Text('⚽', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 22),
          const Text(
            'MATCH MOMENT',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gol, seyv yoki skill — professional lavha yarat',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink.withValues(alpha: 0.65),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          _BigBtn(
            label: 'Galereyadan tanlash',
            icon: Icons.photo_library_outlined,
            onTap: () => onPick(ImageSource.gallery),
          ),
          const SizedBox(height: 10),
          _BigBtn(
            label: 'Kamera bilan yozish',
            icon: Icons.videocam_outlined,
            outline: true,
            onTap: () => onPick(ImageSource.camera),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MomentStep extends StatelessWidget {
  const _MomentStep({
    super.key,
    required this.player,
    required this.moments,
    required this.selected,
    required this.onSelect,
    required this.onNext,
    required this.onBack,
  });

  final VideoPlayerController? player;
  final List<_Moment> moments;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _BroadcastPreview(player: player, label: 'MATCH MOMENT')),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Nima bo‘ldi?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: moments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final m = moments[i];
              final on = selected == m.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(m.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 88,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: on
                        ? AppColors.lime.withValues(alpha: 0.14)
                        : const Color(0xFF0D1711),
                    border: Border.all(
                      color: on
                          ? AppColors.lime
                          : Colors.white.withValues(alpha: 0.08),
                      width: on ? 1.6 : 1,
                    ),
                    boxShadow: on
                        ? [
                            BoxShadow(
                              color: AppColors.lime.withValues(alpha: 0.25),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 6),
                      Text(
                        m.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: on ? AppColors.lime : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Orqaga')),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: const Color(0xFF052E12),
                ),
                onPressed: onNext,
                child: const Text('Davom etish'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorStep extends StatelessWidget {
  const _EditorStep({
    super.key,
    required this.player,
    required this.trimStart,
    required this.trimEnd,
    required this.overlay,
    required this.customText,
    required this.sticker,
    required this.onTrim,
    required this.onOverlay,
    required this.onText,
    required this.onSticker,
    required this.onBack,
    required this.onNext,
  });

  final VideoPlayerController? player;
  final Duration trimStart;
  final Duration trimEnd;
  final String? overlay;
  final String customText;
  final String? sticker;
  final void Function(Duration start, Duration end) onTrim;
  final ValueChanged<String?> onOverlay;
  final ValueChanged<String> onText;
  final ValueChanged<String?> onSticker;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final dur = player?.value.duration ?? Duration.zero;
    final maxMs = dur.inMilliseconds.clamp(1, 999999999).toDouble();
    final start = trimStart.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    final end = trimEnd.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

    return Column(
      children: [
        Expanded(
          child: _BroadcastPreview(
            player: player,
            label: 'EDITOR',
            overlay: overlay,
            customText: customText,
            sticker: sticker,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✂️ Trim  ·  ${(end - start) ~/ 1000}s',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              RangeSlider(
                values: RangeValues(
                  start.clamp(0, maxMs),
                  end.clamp(0, maxMs),
                ),
                min: 0,
                max: maxMs,
                activeColor: AppColors.lime,
                inactiveColor: Colors.white24,
                onChanged: (v) {
                  var a = Duration(milliseconds: v.start.round());
                  var b = Duration(milliseconds: v.end.round());
                  if (b - a < const Duration(seconds: 1)) {
                    b = a + const Duration(seconds: 1);
                    if (b > dur) {
                      b = dur;
                      a = b - const Duration(seconds: 1);
                      if (a < Duration.zero) a = Duration.zero;
                    }
                  }
                  onTrim(a, b);
                  player?.seekTo(a);
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _ToolChip(
                icon: '🏆',
                label: 'Score',
                on: overlay == 'scoreboard',
                onTap: () => onOverlay(
                    overlay == 'scoreboard' ? null : 'scoreboard'),
              ),
              _ToolChip(
                icon: '⚽',
                label: 'Goal',
                on: overlay == 'goal',
                onTap: () {
                  onOverlay(overlay == 'goal' ? null : 'goal');
                  onText('GOAL!');
                },
              ),
              _ToolChip(
                icon: 'Aa',
                label: 'Text',
                on: overlay == 'match',
                onTap: () async {
                  onOverlay('match');
                  final ctrl = TextEditingController(text: customText);
                  final ok = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: const Color(0xFF0D1711),
                    builder: (ctx) => Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.paddingOf(ctx).bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Custom text',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          TextField(controller: ctrl, autofocus: true),
                          const SizedBox(height: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: const Color(0xFF052E12),
                            ),
                            onPressed: () => Navigator.pop(ctx, ctrl.text),
                            child: const Text('Qo‘llash'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (ok != null) onText(ok);
                },
              ),
              _ToolChip(
                icon: '🔥',
                label: 'Sticker',
                on: sticker != null,
                onTap: () {
                  const opts = ['⚽', '🔥', '⚡', '💥', '🏆', '🧤', 'GOOOAL'];
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: const Color(0xFF0D1711),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final s in opts)
                            ActionChip(
                              label: Text(s, style: const TextStyle(fontSize: 20)),
                              onPressed: () {
                                onSticker(s);
                                Navigator.pop(ctx);
                              },
                            ),
                          TextButton(
                            onPressed: () {
                              onSticker(null);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Olib tashlash'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              _ToolChip(
                icon: '✨',
                label: 'Effect',
                on: overlay == 'effect',
                onTap: () =>
                    onOverlay(overlay == 'effect' ? null : 'effect'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Orqaga')),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: const Color(0xFF052E12),
                ),
                onPressed: onNext,
                child: const Text('Next →'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on
            ? AppColors.lime.withValues(alpha: 0.16)
            : const Color(0xFF0D1711),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: on
                    ? AppColors.lime
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                Text(label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: on ? AppColors.lime : AppColors.ink,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionStep extends StatelessWidget {
  const _CaptionStep({
    super.key,
    required this.player,
    required this.caption,
    required this.tracks,
    required this.trackId,
    required this.overlay,
    required this.customText,
    required this.sticker,
    required this.onTrack,
    required this.onBack,
    required this.onPublish,
  });

  final VideoPlayerController? player;
  final TextEditingController caption;
  final List<_Track> tracks;
  final String? trackId;
  final String? overlay;
  final String customText;
  final String? sticker;
  final ValueChanged<String> onTrack;
  final VoidCallback onBack;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SizedBox(
          height: 260,
          child: _BroadcastPreview(
            player: player,
            label: 'PREVIEW',
            overlay: overlay,
            customText: customText,
            sticker: sticker,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Caption',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: caption,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '87-daqiqadagi ajoyib gol! 🔥⚽',
            filled: true,
            fillColor: const Color(0xFF0D1711),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('🎵 Sound',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        ...tracks.map((t) {
          final on = trackId == t.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => onTrack(t.id),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: on
                      ? AppColors.lime
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              tileColor: on
                  ? AppColors.lime.withValues(alpha: 0.1)
                  : const Color(0xFF0D1711),
              leading: Icon(
                on ? Icons.graphic_eq : Icons.music_note_outlined,
                color: on ? AppColors.lime : AppColors.muted,
              ),
              title: Text(t.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(t.category,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              trailing: on
                  ? const Icon(Icons.check_circle, color: AppColors.lime)
                  : null,
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(onPressed: onBack, child: const Text('Orqaga')),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: const Color(0xFF052E12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: onPublish,
              icon: const Icon(Icons.stadium_outlined),
              label: const Text('PUBLISH',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ],
    );
  }
}

class _UploadStep extends StatelessWidget {
  const _UploadStep({
    super.key,
    required this.progress,
    required this.done,
  });
  final double progress;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(done ? '✓' : '⚽', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 18),
            Text(
              done ? 'MATCH MOMENT READY' : 'PREPARING YOUR\nMATCH MOMENT',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                color: AppColors.lime,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              done ? 'Tayyor!' : 'Processing video… ${(progress * 100).round()}%',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastPreview extends StatelessWidget {
  const _BroadcastPreview({
    required this.player,
    required this.label,
    this.overlay,
    this.customText = '',
    this.sticker,
  });
  final VideoPlayerController? player;
  final String label;
  final String? overlay;
  final String customText;
  final String? sticker;

  @override
  Widget build(BuildContext context) {
    final ready = player != null && player!.value.isInitialized;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppColors.lime.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.lime.withValues(alpha: 0.35),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.15),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (ready)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: player!.value.size.width,
                        height: player!.value.size.height,
                        child: VideoPlayer(player!),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF0D1711),
                      alignment: Alignment.center,
                      child: const Icon(Icons.videocam_outlined,
                          color: AppColors.muted, size: 40),
                    ),
                  if (overlay == 'effect')
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.lime.withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  if (overlay == 'scoreboard')
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.lime.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'TEAM A    2 : 1    TEAM B',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  if (overlay == 'goal' || overlay == 'match')
                    Align(
                      alignment: const Alignment(0, 0.55),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lime),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lime.withValues(alpha: 0.35),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Text(
                          customText.isEmpty ? 'GOAL!' : customText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 1.4,
                            color: AppColors.lime,
                          ),
                        ),
                      ),
                    ),
                  if (sticker != null)
                    Positioned(
                      right: 16,
                      bottom: 18,
                      child: Text(sticker!,
                          style: const TextStyle(fontSize: 36)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '⚽ FOOTBALL MOMENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigBtn extends StatelessWidget {
  const _BigBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outline = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    if (outline) {
      return OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: BorderSide(color: AppColors.lime.withValues(alpha: 0.4)),
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: const Color(0xFF052E12),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
