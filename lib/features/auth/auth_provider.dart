import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/constants.dart';
import '../../shared/models/models.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.busy = false,
    this.telegramWaiting = false,
  });

  final AuthStatus status;
  final User? user;
  final String? error;
  final bool busy;
  final bool telegramWaiting;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? busy,
    bool? telegramWaiting,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
      telegramWaiting: telegramWaiting ?? this.telegramWaiting,
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

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(busy: true, clearError: true, telegramWaiting: false);
    try {
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConstants.googleServerClientId.isEmpty
            ? null
            : AppConstants.googleServerClientId,
      );
      final account = await google.signIn();
      if (account == null) {
        state = state.copyWith(busy: false);
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        state = state.copyWith(
          busy: false,
          error: 'Google token olinmadi. Google Cloud client ID sozlang.',
        );
        return false;
      }
      final res = await _api.loginWithGoogle(idToken);
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

  Future<bool> loginWithTelegram() async {
    state = state.copyWith(
      busy: true,
      clearError: true,
      telegramWaiting: true,
    );
    try {
      final start = await _api.startTelegramMobileLogin();
      final uri = Uri.parse(start.deepLink);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        state = state.copyWith(
          busy: false,
          telegramWaiting: false,
          error: 'Telegram ochilmadi',
        );
        return false;
      }

      final deadline = DateTime.now().add(Duration(seconds: start.expiresIn));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!state.telegramWaiting) return false;
        try {
          final user = await _api.pollTelegramMobileLogin(start.loginToken);
          if (user != null) {
            state = AuthState(status: AuthStatus.authenticated, user: user);
            return true;
          }
        } on ApiException catch (e) {
          state = state.copyWith(
            busy: false,
            telegramWaiting: false,
            error: e.message,
          );
          return false;
        }
      }
      state = state.copyWith(
        busy: false,
        telegramWaiting: false,
        error: 'Vaqt tugadi. Botda /start bosing va qayta urinib ko‘ring.',
      );
      return false;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        telegramWaiting: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        busy: false,
        telegramWaiting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void cancelTelegramWait() {
    state = state.copyWith(busy: false, telegramWaiting: false);
  }

  Future<void> refreshMe() async {
    try {
      final user = await _api.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {}
  }

  Future<bool> updateProfile(Map<String, dynamic> payload) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _api.updateMe(payload);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
