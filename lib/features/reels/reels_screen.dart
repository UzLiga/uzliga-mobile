import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_provider.dart';

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

  bool _muted = true;
  bool _uploading = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;
  int _index = 0;
  static const _pageSize = 12;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
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
      setState(() {
        if (reset) {
          _disposePool();
          _clips
            ..clear()
            ..addAll(page.items);
          _index = 0;
        } else {
          _clips.addAll(page.items);
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
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(_urlFor(clip)),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _pool[clip.id] = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(_muted ? 0 : 1);
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
    for (final i in [index - 1, index, index + 1, index + 2]) {
      if (i < 0 || i >= _clips.length) continue;
      final clip = _clips[i];
      keep.add(clip.id);
      _ensureController(clip);
    }
    final drop = _pool.keys.where((id) => !keep.contains(id)).toList();
    for (final id in drop) {
      _pool.remove(id)?.dispose();
    }
    // Play current, pause others
    for (final entry in _pool.entries) {
      final idx = _clips.indexWhere((c) => c.id == entry.key);
      final c = entry.value;
      if (!c.value.isInitialized) continue;
      c.setVolume(_muted ? 0 : 1);
      if (idx == index) {
        c.play();
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

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface2,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galereya'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Kamera (video)'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera (rasm)'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    XFile? file;
    if (choice == 'gallery') {
      file = await picker.pickMedia();
    } else if (choice == 'video') {
      file = await picker.pickVideo(source: ImageSource.camera);
    } else {
      file = await picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    }
    if (file == null || !mounted) return;

    final captionCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Lavha yuklash'),
        content: TextField(
          controller: captionCtrl,
          decoration: const InputDecoration(hintText: 'Caption (ixtiyoriy)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yuklash')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(apiClientProvider).uploadClip(
            filePath: file.path,
            fileName: file.name,
            caption: captionCtrl.text,
          );
      await _load(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lavha yuklandi · HD sifat')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: 'Hali lavha yo‘q',
              subtitle: 'Birinchi video yoki rasmni yuklang',
              icon: Icons.movie_filter_outlined,
              action: ElevatedButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: const Icon(Icons.add),
                label: const Text('Yuklash'),
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
                    for (final c in _pool.values) {
                      c.setVolume(_muted ? 0 : 1);
                    }
                  },
                  onOpenProfile: (uid) => context.push('/app/users/$uid'),
                );
              },
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
              child: Row(
                children: [
                  const Text(
                    'Lavhalar',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() => _muted = !_muted);
                      for (final c in _pool.values) {
                        c.setVolume(_muted ? 0 : 1);
                      }
                    },
                    icon: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _uploading ? null : _pickAndUpload,
                    icon: _uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                  ),
                ],
              ),
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

class _ReelSlideState extends ConsumerState<_ReelSlide> {
  Future<void> _toggleLike() async {
    final prevLiked = widget.clip.likedByMe;
    final prevCount = widget.clip.likeCount;
    setState(() {
      widget.clip.likedByMe = !prevLiked;
      widget.clip.likeCount = (prevCount + (prevLiked ? -1 : 1)).clamp(0, 1 << 30);
    });
    try {
      final updated = await ref.read(apiClientProvider).toggleClipLike(widget.clip.id);
      setState(() {
        widget.clip.likedByMe = updated.likedByMe;
        widget.clip.likeCount = updated.likeCount;
      });
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

  Future<void> _openComments() async {
    final api = ref.read(apiClientProvider);
    final me = ref.read(authProvider).user?.id;
    final textCtrl = TextEditingController();
    List<ClipComment> comments = [];
    try {
      comments = (await api.clipComments(widget.clip.id)).items;
    } catch (_) {}

    if (!mounted) return;
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
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Izohlar', style: TextStyle(fontWeight: FontWeight.w800)),
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
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text('$e')));
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

    return Stack(
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
            imageUrl: (poster != null && poster.isNotEmpty) ? poster : clip.mediaUrl,
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
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              _ActionBtn(
                icon: clip.likedByMe ? Icons.favorite : Icons.favorite_border,
                color: clip.likedByMe ? Colors.redAccent : Colors.white,
                label: '${clip.likeCount}',
                onTap: _toggleLike,
              ),
              const SizedBox(height: 16),
              _ActionBtn(
                icon: Icons.chat_bubble_outline,
                label: '${clip.commentCount}',
                onTap: _openComments,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 80,
          bottom: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => widget.onOpenProfile(clip.userId),
                child: Row(
                  children: [
                    CircleAvatar(
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
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (clip.caption != null && clip.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  clip.caption!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ],
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
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }
}
