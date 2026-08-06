import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'pc_access';
  static const _refreshKey = 'pc_refresh';
  static const _onboardingKey = 'pc_onboarding_done';

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<bool> isOnboardingDone() async {
    final v = await _storage.read(key: _onboardingKey);
    return v == '1';
  }

  Future<void> setOnboardingDone() async {
    await _storage.write(key: _onboardingKey, value: '1');
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  return ref.watch(tokenStorageProvider).isOnboardingDone();
});
