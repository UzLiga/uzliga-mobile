import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Disk cache for reel videos — non-blocking: play network first, cache in background.
class ReelVideoCache {
  ReelVideoCache._();
  static final ReelVideoCache instance = ReelVideoCache._();

  final Map<String, Future<File?>> _inflight = {};
  Directory? _dir;

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final root = await getTemporaryDirectory();
    _dir = Directory('${root.path}/reel_videos');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    return _dir!;
  }

  String _key(String url) => url.hashCode.toUnsigned(32).toRadixString(16);

  /// Instant path if already cached; never blocks on download.
  Future<File?> getCachedOnly(String url) async {
    if (url.isEmpty) return null;
    final dir = await _cacheDir();
    final file = File('${dir.path}/${_key(url)}.mp4');
    if (await file.exists() && await file.length() > 8 * 1024) {
      return file;
    }
    return null;
  }

  /// Fire-and-forget background download (streaming to file).
  void prefetch(Iterable<String> urls) {
    for (final u in urls) {
      if (u.isEmpty) continue;
      // ignore: discarded_futures
      _ensureDownloaded(u);
    }
  }

  Future<File?> _ensureDownloaded(String url) {
    return _inflight.putIfAbsent(url, () async {
      try {
        final dir = await _cacheDir();
        final file = File('${dir.path}/${_key(url)}.mp4');
        if (await file.exists() && await file.length() > 8 * 1024) {
          return file;
        }
        final tmp = File('${file.path}.part');
        final client = http.Client();
        try {
          final req = http.Request('GET', Uri.parse(url));
          final res = await client.send(req).timeout(const Duration(seconds: 60));
          if (res.statusCode != 200) return null;
          final sink = tmp.openWrite();
          await res.stream.pipe(sink);
          await sink.close();
          if (await tmp.length() < 8 * 1024) {
            await tmp.delete();
            return null;
          }
          await tmp.rename(file.path);
          return file;
        } finally {
          client.close();
        }
      } catch (_) {
        return null;
      } finally {
        _inflight.remove(url);
      }
    });
  }
}
