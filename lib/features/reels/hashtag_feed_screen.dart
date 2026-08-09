import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/models/models.dart';

class HashtagFeedScreen extends ConsumerStatefulWidget {
  const HashtagFeedScreen({super.key, required this.tag});

  final String tag;

  @override
  ConsumerState<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends ConsumerState<HashtagFeedScreen> {
  final _clips = <MatchClip>[];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(apiClientProvider).clipsByHashtag(
            widget.tag,
            limit: 60,
          );
      if (!mounted) return;
      setState(() {
        _clips
          ..clear()
          ..addAll(page.items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: pcAppBar(context, title: '#${widget.tag}'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_error'),
                      TextButton(onPressed: _load, child: const Text('Qayta')),
                    ],
                  ),
                )
              : _clips.isEmpty
                  ? const Center(child: Text('Lavha yo‘q'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 9 / 16,
                      ),
                      itemCount: _clips.length,
                      itemBuilder: (_, i) {
                        final c = _clips[i];
                        final cover = c.posterUrl ?? c.mediaUrl;
                        return GestureDetector(
                          onTap: () => context.push('/app'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: cover,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
