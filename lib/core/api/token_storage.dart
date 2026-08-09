import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'pc_access';
  static const _refreshKey = 'pc_refresh';
  static const _onboardingKey = 'pc_onboarding_done';

  String? _accessCache;
  String? _refreshCache;
  bool? _onboardingCache;

  Future<String?> getAccessToken() async {
    if (_accessCache != null) return _accessCache;
    _accessCache = await _storage.read(key: _accessKey);
    return _accessCache;
  }

  Future<String?> getRefreshToken() async {
    if (_refreshCache != null) return _refreshCache;
    _refreshCache = await _storage.read(key: _refreshKey);
    return _refreshCache;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessCache = accessToken;
    _refreshCache = refreshToken;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<bool> isOnboardingDone() async {
    if (_onboardingCache != null) return _onboardingCache!;
    final v = await _storage.read(key: _onboardingKey);
    _onboardingCache = v == '1';
    return _onboardingCache!;
  }

  Future<void> setOnboardingDone() async {
    _onboardingCache = true;
    await _storage.write(key: _onboardingKey, value: '1');
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  return ref.read(tokenStorageProvider).isOnboardingDone();
});
