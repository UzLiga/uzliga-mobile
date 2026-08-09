import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../offline_cache.dart';
import 'token_storage.dart';
import '../../shared/models/models.dart';

export 'token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(tokenStorageProvider));
});

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required TokenStorage storage}) : _storage = storage {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isAuthCall = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/google') ||
              path.contains('/auth/telegram');

          if (status == 401 && !_refreshing && !isAuthCall) {
            _refreshing = true;
            try {
              final refreshed = await _refreshTokens();
              if (refreshed) {
                final req = error.requestOptions;
                final token = await _storage.getAccessToken();
                req.headers['Authorization'] = 'Bearer $token';
                final response = await _dio.fetch(req);
                _refreshing = false;
                return handler.resolve(response);
              }
            } catch (_) {
              await _storage.clear();
            } finally {
              _refreshing = false;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _storage;
  late final Dio _dio;
  bool _refreshing = false;

  Future<bool> _refreshTokens() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    final res = await Dio(
      BaseOptions(baseUrl: AppConstants.apiBase),
    ).post('/auth/refresh', data: {'refresh_token': refresh});
    final data = Map<String, dynamic>.from(res.data as Map);
    await _storage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return true;
  }

  Never _throwDio(DioException e) {
    final data = e.response?.data;
    String message = 'Tarmoq xatosi';
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is Map) {
        message = detail['message']?.toString() ??
            detail['error_code']?.toString() ??
            detail.toString();
      } else if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          message = first['msg'].toString();
        } else {
          message = detail.toString();
        }
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Server javob bermadi';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Internet aloqasi yo‘q';
    }
    throw ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
    bool useCache = true,
  }) async {
    final cacheKey = 'get:$path:${jsonEncode(query ?? const {})}';
    try {
      final res = await _dio.get(path, queryParameters: query);
      if (useCache) {
        await OfflineCache.instance.put(cacheKey, res.data);
      }
      return parse(res.data);
    } on DioException catch (e) {
      final offlineish = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.response == null;
      if (useCache && offlineish) {
        final cached = await OfflineCache.instance.get(cacheKey);
        if (cached != null) {
          return parse(cached);
        }
      }
      _throwDio(e);
    }
  }

  Future<T> _post<T>(
    String path, {
    Object? data,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await _dio.post(path, data: data);
      return parse(res.data);
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<T> _patch<T>(
    String path, {
    Object? data,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await _dio.patch(path, data: data);
      return parse(res.data);
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // —— Auth ——
  Future<({User user, AuthTokens tokens})> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final data = await _post(
      '/auth/register',
      data: {'full_name': fullName, 'phone': phone, 'password': password},
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    final tokens = AuthTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return (user: User.fromJson(Map<String, dynamic>.from(data['user'] as Map)), tokens: tokens);
  }

  Future<({User user, AuthTokens tokens})> login({
    required String phone,
    required String password,
  }) async {
    final data = await _post(
      '/auth/login',
      data: {'phone': phone, 'password': password},
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    if (data['requires_2fa'] == true) {
      throw ApiException('2FA yoqilgan. Hozircha web orqali kiring.');
    }
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null || data['user'] == null) {
      throw ApiException('Login muvaffaqiyatsiz');
    }
    await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    return (
      user: User.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
      tokens: AuthTokens(accessToken: access, refreshToken: refresh),
    );
  }

  Future<({User user, AuthTokens tokens})> loginWithGoogle(String idToken) async {
    final data = await _post(
      '/auth/google',
      data: {'id_token': idToken},
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null || data['user'] == null) {
      throw ApiException('Google kirish muvaffaqiyatsiz');
    }
    await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    return (
      user: User.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
      tokens: AuthTokens(accessToken: access, refreshToken: refresh),
    );
  }

  Future<({String loginToken, String deepLink, int expiresIn})>
      startTelegramMobileLogin() async {
    final data = await _post(
      '/auth/telegram/mobile/start',
      data: const {},
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    return (
      loginToken: data['login_token'] as String,
      deepLink: data['deep_link'] as String,
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 300,
    );
  }

  /// Returns user if confirmed, null if still pending, throws if expired.
  Future<User?> pollTelegramMobileLogin(String loginToken) async {
    final data = await _get(
      '/auth/telegram/mobile/poll',
      query: {'login_token': loginToken},
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    final status = data['status'] as String? ?? 'expired';
    if (status == 'pending') return null;
    if (status != 'confirmed') {
      throw ApiException('Telegram kirish muddati tugadi. Qayta urinib ko‘ring.');
    }
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null || data['user'] == null) {
      throw ApiException('Telegram kirish muvaffaqiyatsiz');
    }
    await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<Map<String, dynamic>> matchmakingFind(int teamId) => _post(
        '/matchmaking/find',
        data: {'team_id': teamId},
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<Map<String, dynamic>> matchmakingStatus(int teamId) => _get(
        '/matchmaking/status',
        query: {'team_id': teamId},
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<Map<String, dynamic>> matchmakingCancel(int teamId) => _post(
        '/matchmaking/cancel',
        data: {'team_id': teamId},
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<User> me() => _get(
        '/users/me',
        parse: (d) => User.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<User> updateMe(Map<String, dynamic> payload) => _patch(
        '/users/me',
        data: payload,
        parse: (d) => User.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<User> uploadAvatar({
    required String filePath,
    required String fileName,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final res = await _dio.post(
        '/users/me/avatar',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 1),
          receiveTimeout: const Duration(minutes: 1),
        ),
      );
      return User.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<Map<String, dynamic>> subscribePremium({String provider = 'card'}) =>
      _post(
        '/premium/subscribe',
        data: {'provider': provider},
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<Map<String, dynamic>> premiumStatus() => _get(
        '/premium/status',
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<Map<String, dynamic>> uploadPremiumPaymentProof({
    required int paymentId,
    required String filePath,
    String fileName = 'premium_proof.jpg',
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final res = await _dio.post(
        '/premium/payments/$paymentId/proof',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<void> logout() => _storage.clear();

  // —— Stadiums ——
  Future<PageResult<Stadium>> listStadiums({
    String? search,
    String? district,
    int? minPrice,
    int? maxPrice,
    String sort = '-rating',
    int limit = 20,
    int offset = 0,
  }) {
    return _get(
      '/stadiums',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (district != null && district.isNotEmpty) 'district': district,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        'sort': sort,
        'limit': limit,
        'offset': offset,
      },
      parse: (d) => PageResult.fromJson(
        Map<String, dynamic>.from(d as Map),
        Stadium.fromJson,
      ),
    );
  }

  Future<Stadium> getStadium(int id) => _get(
        '/stadiums/$id',
        parse: (d) => Stadium.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<Availability> stadiumAvailability(int id, String date) => _get(
        '/stadiums/$id/availability',
        query: {'date': date},
        parse: (d) => Availability.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<List<String>> districts() => _get(
        '/stadiums/districts',
        parse: (d) {
          final map = Map<String, dynamic>.from(d as Map);
          return (map['items'] as List? ?? const []).map((e) => e.toString()).toList();
        },
      );

  // —— Bookings ——
  Future<Booking> createBooking({
    required int stadiumId,
    required String date,
    required String startTime,
    required int durationHours,
  }) =>
      _post(
        '/bookings',
        data: {
          'stadium_id': stadiumId,
          'date': date,
          'start_time': startTime,
          'duration_hours': durationHours,
        },
        parse: (d) => Booking.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<PageResult<Booking>> myBookings({int limit = 20, int offset = 0}) =>
      _get(
        '/bookings/my',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          Booking.fromJson,
        ),
      );

  Future<Booking> payBooking(int id) => _post(
        '/bookings/$id/pay',
        parse: (d) => Booking.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  /// To‘lov cheki (rasm) — egaga yetadi.
  Future<String> uploadBookingPaymentProof({
    required int bookingId,
    required String filePath,
    String fileName = 'payment_proof.jpg',
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final res = await _dio.post(
        '/bookings/$bookingId/payment-proof',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 1),
          receiveTimeout: const Duration(minutes: 1),
        ),
      );
      final map = Map<String, dynamic>.from(res.data as Map);
      return map['payment_proof_url']?.toString() ?? '';
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  /// Checkout hold (§4.1) — slot lock ~10 min
  Future<Map<String, dynamic>> checkoutHold({
    required int stadiumId,
    required String date,
    required String startTime,
    required String endTime,
  }) =>
      _post(
        '/bookings/checkout/hold',
        data: {
          'stadium_id': stadiumId,
          'date': date,
          'start_time': startTime,
          'end_time': endTime,
        },
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  /// Confirm hold with payment provider: fake|click|payme|cash|card
  Future<Map<String, dynamic>> checkoutConfirm({
    required int holdId,
    String provider = 'click',
    String? cardNumber,
    String? cardHolder,
  }) =>
      _post(
        '/bookings/checkout/confirm',
        data: {
          'hold_id': holdId,
          'provider': provider,
          if (cardNumber != null) 'card_number': cardNumber,
          if (cardHolder != null) 'card_holder': cardHolder,
        },
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<String> bookingQr(int id) => _get(
        '/bookings/$id/qr',
        parse: (d) => Map<String, dynamic>.from(d as Map)['qr_payload'] as String,
      );

  Future<Booking> cancelBooking(int id) async {
    final data = await _post(
      '/bookings/$id/cancel',
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    final bookingMap = data['booking'];
    if (bookingMap is Map) {
      return Booking.fromJson(Map<String, dynamic>.from(bookingMap));
    }
    // legacy flat BookingOut
    return Booking.fromJson(data);
  }

  /// Cancel with refund policy details.
  Future<({Booking booking, int refundAmount, String policy, String message})>
      cancelBookingDetailed(int id) async {
    final data = await _post(
      '/bookings/$id/cancel',
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    final bookingMap = data['booking'];
    final booking = bookingMap is Map
        ? Booking.fromJson(Map<String, dynamic>.from(bookingMap))
        : Booking.fromJson(data);
    return (
      booking: booking,
      refundAmount: (data['refund_amount'] as num?)?.toInt() ?? 0,
      policy: '${data['refund_policy'] ?? 'none'}',
      message: '${data['message'] ?? 'Bron bekor qilindi'}',
    );
  }

  Future<void> registerDeviceToken(String token, {String? platform}) async {
    await _post(
      '/users/me/device-token',
      data: {'token': token, if (platform != null) 'platform': platform},
      parse: (_) => true,
    );
  }

  // —— Platform features ——
  Future<Map<String, dynamic>> createTeamBooking(Map<String, dynamic> data) =>
      _post('/bookings/team', data: data, parse: (d) => Map<String, dynamic>.from(d as Map));

  Future<Map<String, dynamic>> joinTeamBooking(String inviteCode) => _post(
        '/bookings/team/join',
        data: {'invite_code': inviteCode, 'provider': 'fake'},
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<Map<String, dynamic>> createRecurring(Map<String, dynamic> data) =>
      _post('/bookings/recurring', data: data, parse: (d) => Map<String, dynamic>.from(d as Map));

  Future<Map<String, dynamic>> joinWaitlist(Map<String, dynamic> data) =>
      _post('/waitlist', data: data, parse: (d) => Map<String, dynamic>.from(d as Map));

  Future<List<Map<String, dynamic>>> listStories({int? stadiumId}) => _get(
        '/stories',
        query: {if (stadiumId != null) 'stadium_id': stadiumId},
        parse: (d) => (d as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );

  Future<List<Map<String, dynamic>>> listReferees({String? city}) => _get(
        '/referees',
        query: {if (city != null) 'city': city},
        parse: (d) => (d as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );

  Future<Map<String, dynamic>> bookReferee(Map<String, dynamic> data) =>
      _post('/referees/book', data: data, parse: (d) => Map<String, dynamic>.from(d as Map));

  // —— Battles / availability / team hub ——
  Future<List<Map<String, dynamic>>> listBattles() => _get(
        '/battles',
        parse: (d) =>
            (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );

  Future<Map<String, dynamic>> joinBattle(int id) => _post(
        '/battles/$id/join',
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<Map<String, dynamic>> setAvailability(Map<String, dynamic> data) =>
      _patch('/me/availability', data: data, parse: (d) => Map<String, dynamic>.from(d as Map));

  Future<List<Map<String, dynamic>>> suggestPlayersForTeam(int teamId) => _get(
        '/team-hub/$teamId/suggest-players',
        parse: (d) =>
            (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );

  Future<List<Map<String, dynamic>>> suggestOpponents(int teamId) => _get(
        '/team-hub/$teamId/suggest-opponents',
        parse: (d) =>
            (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );

  Future<Map<String, dynamic>> sendTeamChallenge(Map<String, dynamic> data) =>
      _post('/team-challenges', data: data, parse: (d) => Map<String, dynamic>.from(d as Map));

  // —— Games ——
  Future<PageResult<Game>> listGames({
    String? status,
    String? format,
    String? date,
    int limit = 20,
    int offset = 0,
  }) =>
      _get(
        '/games',
        query: {
          if (status != null) 'status': status,
          if (format != null) 'format': format,
          if (date != null) 'date': date,
          'limit': limit,
          'offset': offset,
        },
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          Game.fromJson,
        ),
      );

  Future<PageResult<Game>> myGames({
    String? status,
    int limit = 40,
    int offset = 0,
  }) =>
      _get(
        '/games/mine',
        query: {
          if (status != null) 'status': status,
          'limit': limit,
          'offset': offset,
        },
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          Game.fromJson,
        ),
      );

  Future<GameDetail> getGame(int id) => _get(
        '/games/$id',
        parse: (d) => GameDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<GameDetail> joinGame(int id) => _post(
        '/games/$id/join',
        parse: (d) => GameDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<GameDetail> leaveGame(int id) => _post(
        '/games/$id/leave',
        parse: (d) => GameDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<GameDetail> createGame(Map<String, dynamic> payload) => _post(
        '/games',
        data: payload,
        parse: (d) => GameDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  // —— Teams ——
  Future<PageResult<Team>> listTeams({
    String? search,
    int limit = 20,
    int offset = 0,
  }) =>
      _get(
        '/teams',
        query: {
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': limit,
          'offset': offset,
        },
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          Team.fromJson,
        ),
      );

  Future<PageResult<Team>> myTeams({int limit = 20, int offset = 0}) => _get(
        '/teams/my',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          Team.fromJson,
        ),
      );

  Future<TeamDetail> getTeam(int id) => _get(
        '/teams/$id',
        parse: (d) => TeamDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<TeamDetail> createTeam({
    required String name,
    String? description,
    int formatSize = 7,
    String? district,
  }) =>
      _post(
        '/teams',
        data: {
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
          'format_size': formatSize,
          if (district != null) 'district': district,
        },
        parse: (d) => TeamDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<TeamDetail> joinTeam(int id) => _post(
        '/teams/$id/join',
        parse: (d) => TeamDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  // —— Users ——
  Future<User> getUser(int id) => _get(
        '/users/$id',
        parse: (d) => User.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  // —— Clips / Lavhalar ——
  Future<PageResult<MatchClip>> clipsFeed({int limit = 10, int offset = 0}) =>
      _get(
        '/clips/feed',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          MatchClip.fromJson,
        ),
      );

  Future<PageResult<MatchClip>> clipsByHashtag(
    String tag, {
    int limit = 30,
    int offset = 0,
  }) =>
      _get(
        '/clips/tag/${Uri.encodeComponent(tag)}',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          MatchClip.fromJson,
        ),
      );

  Future<PageResult<MatchClip>> myClips({int limit = 30, int offset = 0}) =>
      _get(
        '/clips/mine',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          MatchClip.fromJson,
        ),
      );

  Future<PageResult<MatchClip>> userClips(
    int userId, {
    int limit = 30,
    int offset = 0,
  }) =>
      _get(
        '/clips/user/$userId',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          MatchClip.fromJson,
        ),
      );

  Future<MatchClip> toggleClipLike(int id) => _post(
        '/clips/$id/like',
        parse: (d) => MatchClip.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<void> viewClip(int id) async {
    try {
      await _dio.post('/clips/$id/view');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<PageResult<ClipComment>> clipComments(
    int clipId, {
    int limit = 50,
    int offset = 0,
  }) =>
      _get(
        '/clips/$clipId/comments',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          ClipComment.fromJson,
        ),
      );

  Future<ClipComment> addClipComment(int clipId, String body) => _post(
        '/clips/$clipId/comments',
        data: {'body': body},
        parse: (d) => ClipComment.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<void> deleteClipComment(int commentId) async {
    try {
      await _dio.delete('/clips/comments/$commentId');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<MatchClip> uploadClip({
    required String filePath,
    required String fileName,
    String? caption,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
      });
      final res = await _dio.post(
        '/clips/upload',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return MatchClip.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<MatchClip> patchClip(int id, {required String caption}) => _patch(
        '/clips/$id',
        data: {'caption': caption},
        parse: (d) => MatchClip.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<void> deleteClip(int id) async {
    try {
      await _dio.delete('/clips/$id');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<PageResult<MatchClip>> clipsByTag(
    String tag, {
    int limit = 30,
    int offset = 0,
  }) =>
      _get(
        '/clips/tag/${Uri.encodeComponent(tag)}',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          MatchClip.fromJson,
        ),
      );

  // —— Tournaments ——
  Future<PageResult<Tournament>> listTournaments({int limit = 30, int offset = 0}) =>
      _get(
        '/tournaments',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          Tournament.fromJson,
        ),
      );

  Future<TournamentDetail> getTournament(int id) => _get(
        '/tournaments/$id',
        parse: (d) => TournamentDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<TournamentDetail> joinTournament({
    required int tournamentId,
    required int teamId,
  }) =>
      _post(
        '/tournaments/$tournamentId/join',
        data: {'team_id': teamId},
        parse: (d) => TournamentDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  // —— Free agents ——
  Future<PageResult<FreeAgentPost>> listFreeAgents({
    String? type,
    int limit = 30,
    int offset = 0,
  }) =>
      _get(
        '/free-agents',
        query: {
          if (type != null) 'type': type,
          'limit': limit,
          'offset': offset,
        },
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          FreeAgentPost.fromJson,
        ),
      );

  Future<FreeAgentPost> createFreeAgent({
    required String type,
    required String comment,
    String? position,
    String? locationText,
  }) =>
      _post(
        '/free-agents',
        data: {
          'type': type,
          'comment': comment,
          if (position != null && position.isNotEmpty) 'position': position,
          if (locationText != null && locationText.isNotEmpty)
            'location_text': locationText,
        },
        parse: (d) => FreeAgentPost.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<void> closeFreeAgent(int id) async {
    try {
      await _dio.post('/free-agents/$id/close');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // —— Notifications ——
  Future<PageResult<AppNotification>> listNotifications({int limit = 30, int offset = 0}) =>
      _get(
        '/notifications',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => PageResult.fromJson(
          Map<String, dynamic>.from(d as Map),
          AppNotification.fromJson,
        ),
      );

  Future<int> unreadNotifications() async {
    final data = await _get(
      '/notifications/unread-count',
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    try {
      await _dio.post('/notifications/$id/read');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _dio.post('/notifications/read-all');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // —— Wallet ——
  Future<WalletInfo> getWallet({int limit = 20, int offset = 0}) => _get(
        '/wallet',
        query: {'limit': limit, 'offset': offset},
        parse: (d) => WalletInfo.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<Map<String, dynamic>> topUp({required int amount, String provider = 'fake'}) =>
      _post(
        '/payments/top-up',
        data: {'amount': amount, 'provider': provider},
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );

  Future<void> completePayment(int paymentId) async {
    try {
      await _dio.post('/payments/complete/$paymentId');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // —— Team invite ——
  Future<TeamInvitePreview> getTeamInvitePreview(String code) => _get(
        '/teams/invite/$code',
        parse: (d) =>
            TeamInvitePreview.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<TeamDetail> acceptTeamInvite(String code) => _post(
        '/teams/invite/$code/accept',
        parse: (d) => TeamDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<TeamDetail> regenerateTeamInvite(int teamId) => _post(
        '/teams/$teamId/invite/regenerate',
        parse: (d) => TeamDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

}
