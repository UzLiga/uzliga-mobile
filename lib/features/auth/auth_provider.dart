import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.busy = false,
  });

  final AuthStatus status;
  final User? user;
  final String? error;
  final bool busy;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? busy,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(bootstrap);
    return const AuthState(status: AuthStatus.unknown);
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> bootstrap() async {
    final storage = ref.read(tokenStorageProvider);
    final access = await storage.getAccessToken();
    if (access == null || access.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _api.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      await storage.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String phone, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await _api.login(phone: phone, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: res.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(String fullName, String phone, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await _api.register(
        fullName: fullName,
        phone: phone,
        password: password,
      );
      state = AuthState(status: AuthStatus.authenticated, user: res.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      return false;
    }
  }

  Future<void> refreshMe() async {
    try {
      final user = await _api.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _api.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
