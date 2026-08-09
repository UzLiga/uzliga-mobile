import 'package:audio_session/audio_session.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/video_cache.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';
import '../shell/shell_screen.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final _pageController = PageController();
  final List<MatchClip> _clips = [];
  final Map<int, VideoPlayerController> _pool = {};
  final Set<int> _viewed = {};
  List<Map<String, dynamic>> _stories = const [];

  bool _muted = false; // Instagram-style: audio on by default
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;
  int _index = 0;
  static const _pageSize = 12;

  @override
  void initState() {
    super.initState();
    // Don't block first frame — load after paint (Instagram-like)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepareAudio();
      _load(reset: true);
      _loadStories();
    });
  }

  Future<void> _loadStories() async {
    try {
      final list = await ref.read(apiClientProvider).listStories();
      if (mounted) setState(() => _stories = list);
    } catch (_) {}
  }

  void _openStory(Map<String, dynamic> s) {
    final url = '${s['media_url'] ?? ''}';
    final name = '${s['stadium_name'] ?? 'Stadion'}';
    final caption = s['caption'] as String?;
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent, Colors.black87],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 16,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 2),
                          gradient: const LinearGradient(
                            colors: [AppColors.gold, AppColors.goldDark],
                          ),
                        ),
                        child: const Icon(Icons.stadium,
                            size: 18, color: Color(0xFF1A1000)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (caption != null && caption.isNotEmpty)
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 24,
                    child: Text(
                      caption,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pauseAll() {
    for (final c in _pool.values) {
      if (c.value.isInitialized) c.pause();
    }
  }

  Future<void> _prepareAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.moviePlayback,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.movie,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      await session.setActive(true);
    } catch (_) {}
  }

  Future<void> _ensureAudioFocus() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
  }

  void _applyVolume() {
    for (final c in _pool.values) {
      if (c.value.isInitialized) {
        c.setVolume(_muted ? 0 : 1);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _pool.values) {
      c.dispose();
    }
    _pool.clear();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final offset = reset ? 0 : _clips.length;
      final page = await ref.read(apiClientProvider).clipsFeed(
            limit: _pageSize,
            offset: offset,
          );
      if (!mounted) return;
      final existing = {for (final c in _clips) c.id};
      final fresh = <MatchClip>[];
      for (final c in page.items) {
        if (existing.add(c.id)) fresh.add(c);
      }
      setState(() {
        if (reset) {
          _disposePool();
          _clips
            ..clear()
            ..addAll(fresh);
          _index = 0;
        } else {
          _clips.addAll(fresh);
        }
        _hasMore = _clips.length < page.total && page.items.isNotEmpty;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      _warmAround(_index);
      if (_clips.isNotEmpty) _markView(_clips[_index.clamp(0, _clips.length - 1)]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _disposePool() {
    for (final c in _pool.values) {
      c.dispose();
    }
    _pool.clear();
  }

  String _urlFor(MatchClip clip) => clip.streamUrl;

  Future<void> _ensureController(MatchClip clip) async {
    if (clip.mediaType != 'video') return;
    if (_pool.containsKey(clip.id)) return;
    final url = _urlFor(clip);
    // Prefer already-cached file; otherwise network immediately (no wait on full download)
    final cached = await ReelVideoCache.instance.getCachedOnly(url);
    final ctrl = cached != null
        ? VideoPlayerController.file(
            cached,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
            httpHeaders: const {'Accept': '*/*'},
          );
    // Background cache while playing
    if (cached == null) {
      ReelVideoCache.instance.prefetch([url]);
    }
    _pool[clip.id] = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(_muted ? 0.0 : 1.0);
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      await ctrl.dispose();
      _pool.remove(clip.id);
    }
  }

  void _warmAround(int index) {
    if (_clips.isEmpty) return;
    final keep = <int>{};
    final prefetchUrls = <String>[];
    // Only current + next (Instagram-like) — avoid freezing on 5 decoders
    for (final i in [index, index + 1]) {
      if (i < 0 || i >= _clips.length) continue;
      final clip = _clips[i];
      keep.add(clip.id);
      if (clip.mediaType == 'video') {
        prefetchUrls.add(_urlFor(clip));
        _ensureController(clip);
      }
    }
    // Keep previous briefly paused if already warm
    if (index - 1 >= 0) {
      keep.add(_clips[index - 1].id);
    }
    ReelVideoCache.instance.prefetch(prefetchUrls);
    final drop = _pool.keys.where((id) => !keep.contains(id)).toList();
    for (final id in drop) {
      _pool.remove(id)?.dispose();
    }
    for (final entry in _pool.entries) {
      final idx = _clips.indexWhere((c) => c.id == entry.key);
      final c = entry.value;
      if (!c.value.isInitialized) continue;
      c.setVolume(_muted ? 0.0 : 1.0);
      if (idx == index) {
        // ignore: discarded_futures
        _ensureAudioFocus();
        c.setVolume(_muted ? 0.0 : 1.0);
        c.play();
        Future.delayed(const Duration(milliseconds: 120), () {
          if (!mounted || _muted) return;
          if (c.value.isInitialized) c.setVolume(1.0);
        });
      } else {
        c.pause();
      }
    }
    if (mounted) setState(() {});
  }

  void _markView(MatchClip clip) {
    if (_viewed.contains(clip.id)) return;
    _viewed.add(clip.id);
    ref.read(apiClientProvider).viewClip(clip.id).catchError((_) {});
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _warmAround(index);
    _markView(_clips[index]);
    if (index >= _clips.length - 3) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabIndexProvider, (prev, next) {
      if (next != 2) {
        _pauseAll();
      } else if (_clips.isNotEmpty) {
        _warmAround(_index);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            ErrorView(
              message: _error.toString(),
              onRetry: () => _load(reset: true),
            )
          else if (_clips.isEmpty)
            EmptyState(
              title: 'Lavhalar bo‘sh',
              subtitle: 'Profil → Mening reels dan video yuklang',
              icon: Icons.movie_filter_outlined,
              action: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push('/app/my-reels'),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Profil reels'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('Yangilash'),
                  ),
                ],
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _clips.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final clip = _clips[index];
                return _ReelSlide(
                  clip: clip,
                  muted: _muted,
                  controller: _pool[clip.id],
                  onToggleMute: () {
                    setState(() => _muted = !_muted);
                    _applyVolume();
                  },
                  onOpenProfile: (uid) => context.push('/app/users/$uid'),
                );
              },
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Lavhalar',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      // Upload moved to Profile → Mening reels
                    ],
                  ),
                ),
                if (_stories.isNotEmpty)
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      itemCount: _stories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final s = _stories[i];
                        final name = '${s['stadium_name'] ?? 'Stadion'}';
                        final media = '${s['media_url'] ?? ''}';
                        return GestureDetector(
                          onTap: () => _openStory(s),
                          child: SizedBox(
                            width: 68,
                            child: Column(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.gold,
                                        Color(0xFFF59E0B),
                                        AppColors.goldDark,
                                      ],
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: media.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: media,
                                              fit: BoxFit.cover,
                                              width: 50,
                                              height: 50,
                                            )
                                          : Container(
                                              color: AppColors.surface2,
                                              child: const Icon(Icons.stadium,
                                                  color: AppColors.gold,
                                                  size: 22),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_loadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReelSlide extends ConsumerStatefulWidget {
  const _ReelSlide({
    required this.clip,
    required this.muted,
    required this.onToggleMute,
    required this.onOpenProfile,
    this.controller,
  });

  final MatchClip clip;
  final bool muted;
  final VoidCallback onToggleMute;
  final void Function(int userId) onOpenProfile;
  final VideoPlayerController? controller;

  @override
  ConsumerState<_ReelSlide> createState() => _ReelSlideState();
}

class _ReelSlideState extends ConsumerState<_ReelSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike({bool forceLike = false}) async {
    final prevLiked = widget.clip.likedByMe;
    final prevCount = widget.clip.likeCount;
    if (forceLike && prevLiked) {
      _pulseHeart();
      return;
    }
    setState(() {
      widget.clip.likedByMe = forceLike ? true : !prevLiked;
      if (forceLike && !prevLiked) {
        widget.clip.likeCount = prevCount + 1;
      } else if (!forceLike) {
        widget.clip.likeCount =
            (prevCount + (prevLiked ? -1 : 1)).clamp(0, 1 << 30);
      }
    });
    if (forceLike || widget.clip.likedByMe) _pulseHeart();
    try {
      final updated =
          await ref.read(apiClientProvider).toggleClipLike(widget.clip.id);
      // If forceLike and server unliked (toggle), like again
      if (forceLike && !updated.likedByMe) {
        final again =
            await ref.read(apiClientProvider).toggleClipLike(widget.clip.id);
        setState(() {
          widget.clip.likedByMe = again.likedByMe;
          widget.clip.likeCount = again.likeCount;
        });
      } else {
        setState(() {
          widget.clip.likedByMe = updated.likedByMe;
          widget.clip.likeCount = updated.likeCount;
        });
      }
    } catch (e) {
      setState(() {
        widget.clip.likedByMe = prevLiked;
        widget.clip.likeCount = prevCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _pulseHeart() {
    HapticFeedback.lightImpact();
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  Future<void> _openComments() async {
    final api = ref.read(apiClientProvider);
    final me = ref.read(authProvider).user?.id;
    final textCtrl = TextEditingController();
    List<ClipComment> comments = [];
    try {
      comments = (await api.clipComments(widget.clip.id)).items;
    } catch (_) {}

    if (!mounted) return;
    var sheetMuted = widget.muted;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.55,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Izohlar',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          // Instagram-like: tiny mute only inside comments
                          IconButton(
                            tooltip: sheetMuted ? 'Ovoz yoqish' : 'Ovozni o‘chirish',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: () {
                              widget.onToggleMute();
                              setModal(() => sheetMuted = !sheetMuted);
                            },
                            icon: Icon(
                              sheetMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: AppColors.muted,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: comments.isEmpty
                          ? const Center(child: Text('Izoh yo‘q', style: TextStyle(color: AppColors.muted)))
                          : ListView.builder(
                              itemCount: comments.length,
                              itemBuilder: (_, i) {
                                final c = comments[i];
                                return ListTile(
                                  title: Text(c.user?.fullName ?? 'O‘yinchi',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  subtitle: Text(c.body),
                                  trailing: (c.userId == me)
                                      ? IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          onPressed: () async {
                                            await api.deleteClipComment(c.id);
                                            setModal(() {
                                              comments = List.from(comments)..removeAt(i);
                                            });
                                          },
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textCtrl,
                              decoration: const InputDecoration(hintText: 'Izoh yozing...'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: () async {
                              final body = textCtrl.text.trim();
                              if (body.isEmpty) return;
                              try {
                                final c = await api.addClipComment(widget.clip.id, body);
                                setModal(() {
                                  comments = [c, ...comments];
                                  textCtrl.clear();
                                });
                                setState(() => widget.clip.commentCount += 1);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('$e')));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final video = widget.controller;
    final poster = clip.posterUrl;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => _toggleLike(forceLike: true),
      onTap: () {
        final v = widget.controller;
        if (v == null || !v.value.isInitialized) return;
        if (v.value.isPlaying) {
          v.pause();
        } else {
          v.play();
        }
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (clip.mediaType == 'video') ...[
            if (poster != null && poster.isNotEmpty)
              CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
            if (video != null && video.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: video.value.size.width,
                  height: video.value.size.height,
                  child: VideoPlayer(video),
                ),
              )
            else if (poster == null || poster.isEmpty)
              const Center(child: CircularProgressIndicator()),
          ] else
            CachedNetworkImage(
              imageUrl:
                  (poster != null && poster.isNotEmpty) ? poster : clip.mediaUrl,
              fit: BoxFit.cover,
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, Colors.black87],
                stops: [0, 0.35, 1],
              ),
            ),
          ),
          if (_showHeart)
            Center(
              child: ScaleTransition(
                scale: TweenSequence<double>([
                  TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.25), weight: 40),
                  TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 30),
                  TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
                ]).animate(CurvedAnimation(
                  parent: _heartCtrl,
                  curve: Curves.easeOut,
                )),
                child: const Icon(Icons.favorite,
                    color: AppColors.gold, size: 96),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                _ActionBtn(
                  icon: clip.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: clip.likedByMe ? AppColors.gold : Colors.white,
                  label: '${clip.likeCount}',
                  onTap: () => _toggleLike(),
                ),
                const SizedBox(height: 12),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: '${clip.commentCount}',
                  onTap: _openComments,
                ),
                if (ref.watch(authProvider).user?.id == clip.userId) ...[
                  const SizedBox(height: 12),
                  _ActionBtn(
                    icon: Icons.more_horiz,
                    label: '···',
                    onTap: () => context.push('/app/my-reels'),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 80, 36),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC0B1510)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => widget.onOpenProfile(clip.userId),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.7),
                                width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: clip.user?.avatarUrl != null
                                ? NetworkImage(clip.user!.avatarUrl!)
                                : null,
                            child: clip.user?.avatarUrl == null
                                ? Text((clip.user?.fullName.isNotEmpty == true)
                                    ? clip.user!.fullName[0]
                                    : '?')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clip.user?.fullName ?? 'O‘yinchi',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                clip.stadiumName != null
                                    ? '${clip.stadiumName} · ${clip.matchDate ?? ''}'
                                    : 'Playzon lavha',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (clip.caption != null && clip.caption!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      clip.caption!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (clip.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in clip.hashtags.take(6))
                          GestureDetector(
                            onTap: () => context.push('/app/hashtag/$t'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color:
                                      AppColors.gold.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                '#$t',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
