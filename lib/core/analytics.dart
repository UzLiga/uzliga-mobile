import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight product funnel log (local). Ready to swap for Amplitude later.
class Analytics {
  static const _key = 'playzon_analytics_events';

  static Future<void> log(String event, [Map<String, String>? props]) async {
    final line =
        '${DateTime.now().toIso8601String()}|$event|${props?.entries.map((e) => '${e.key}=${e.value}').join(',') ?? ''}';
    if (kDebugMode) {
      // ignore: avoid_print
      print('[analytics] $line');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      list.add(line);
      if (list.length > 200) {
        list.removeRange(0, list.length - 200);
      }
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<List<String>> recent({int limit = 40}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      return list.reversed.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }
}
