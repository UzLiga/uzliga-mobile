import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Disk JSON cache — offline’da oxirgi muvaffaqiyatli javobni ko‘rsatadi.
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  Future<void> put(String key, Object data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('oc_$key', jsonEncode({
      'ts': DateTime.now().toIso8601String(),
      'data': data,
    }));
  }

  Future<Object?> get(String key, {Duration maxAge = const Duration(days: 7)}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('oc_$key');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ts = DateTime.tryParse(map['ts'] as String? ?? '');
      if (ts != null && DateTime.now().difference(ts) > maxAge) return null;
      return map['data'];
    } catch (_) {
      return null;
    }
  }
}

class ConnectivityState {
  const ConnectivityState({required this.online});
  final bool online;
}

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  ConnectivityState build() {
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      state = ConnectivityState(online: online);
    });
    ref.onDispose(() => _sub?.cancel());
    // initial
    Future.microtask(() async {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      state = ConnectivityState(online: online);
    });
    return const ConnectivityState(online: true);
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(
  ConnectivityNotifier.new,
);
