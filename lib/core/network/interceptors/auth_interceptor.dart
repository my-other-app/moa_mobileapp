import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:finnet/core/auth/session_events.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';

/// Called when the server has ended the stored session.
typedef SessionEndedCallback = void Function(SessionEndReason reason);

/// Interceptor that automatically adds authentication token to requests.
///
/// Handles:
/// - Adding Bearer token to Authorization header
/// - Skipping auth for specific requests (using 'skipAuth' extra)
/// - Token refresh on 401 errors, then one retry of the request. Exactly one
///   refresh runs at a time, shared by every request that hit a 401 while
///   it runs; a 401 for a token a finished refresh already replaced is
///   retried with the new token rather than refreshed again. The server
///   rotates refresh tokens and ends the session when an old one comes back
///   (SESSION_REUSED), so a second refresh is never harmless
/// - Ending the session -- tokens deleted, [onSessionEnded] told -- when the
///   refresh is refused or the account is suspended
class AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;
  final Dio _dio;
  final SessionEndedCallback _onSessionEnded;

  /// The refresh in flight, shared by every request that hit a 401 while it
  /// runs. It used to be a busy-wait over a queue that was never drained
  /// when the refresh failed, so those requests hung forever.
  Future<_RefreshOutcome>? _refreshing;

  /// Marks a request already retried after a refresh, so a 401 that a fresh
  /// token does not cure is reported rather than refreshed again. Without it
  /// the volunteer check-in, which answers 401 for "not a volunteer here",
  /// refreshed and retried until the rate limiter stopped it.
  static const _retriedKey = 'authRetried';

  /// The `Authorization` headers of access tokens a refresh here replaced,
  /// newest last. A 401 for one of them is retried with the current token,
  /// never refreshed again.
  final _replaced = <String>{};
  static const _replacedKept = 8;

  AuthInterceptor(
    this._secureStorage,
    this._dio, {
    SessionEndedCallback? onSessionEnded,
  }) : _onSessionEnded = onSessionEnded ?? SessionEvents.reportRevoked;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check if this request should skip authentication
    final skipAuth = options.extra['skipAuth'] == true;

    if (!skipAuth) {
      try {
        final token = await _secureStorage.getAccessToken();

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        debugPrint('AuthInterceptor: Error getting token: $e');
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final status = err.response?.statusCode;
    // Sign-in calls and the refresh itself are sent with skipAuth: their 401
    // means "wrong password" or "dead refresh token", not "refresh me".
    final sentWithSession = options.extra['skipAuth'] != true;

    if (!sentWithSession) {
      handler.next(err);
      return;
    }

    // Suspension bites on every request, and nothing the app can do lifts
    // it: end the session so the person is shown why, not a broken screen.
    if (status == 403 && _errorCode(err.response?.data) == 'ACCOUNT_SUSPENDED') {
      await _endSession(SessionEndReason.suspended);
      handler.next(err);
      return;
    }

    if (status != 401 || options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }

    final sent = options.headers['Authorization'];

    // Sent before a refresh that has since finished: the token it carried
    // was replaced while it was out. Refreshing again would spend the new
    // refresh token for nothing (the server issues a new one on every
    // refresh), so it is sent again with the stored token instead.
    if (_refreshing == null) {
      final stored = await _readOrNull(_secureStorage.getAccessToken);
      if (stored != null && stored.isNotEmpty && sent != 'Bearer $stored') {
        debugPrint('AuthInterceptor: 401 on ${options.path} with a replaced '
            'token, retrying with the current one');
        await _retry(options, handler);
        return;
      }
    }

    // From here to the refresh there is no await, so the decision is made
    // in one piece. The storage read above can return the old token after
    // a refresh that started and finished while it ran (five requests that
    // 401 together, one of them slow to read the store); the token that
    // refresh replaced is remembered, so this one is retried rather than
    // starting a second refresh with the token the first just issued.
    final running = _refreshing;
    if (running == null && sent is String && _replaced.contains(sent)) {
      debugPrint('AuthInterceptor: 401 on ${options.path} from before the '
          'last refresh, retrying with the current token');
      await _retry(options, handler);
      return;
    }

    debugPrint('AuthInterceptor: 401 on ${options.path}, '
        '${running == null ? 'refreshing' : 'waiting for the refresh'}');
    final outcome = await (running ??
        (_refreshing = _refresh().whenComplete(() {
          _refreshing = null;
        })));

    switch (outcome) {
      case _RefreshOutcome.refreshed:
        await _retry(options, handler);
      case _RefreshOutcome.sessionEnded:
        handler.next(_sessionEnded(err));
      case _RefreshOutcome.unavailable:
        // A network failure, or the server failing: the session may be fine,
        // so it is kept and the original error reported.
        handler.next(err);
    }
  }

  Future<_RefreshOutcome> _refresh() async {
    final replacing = await _readOrNull(_secureStorage.getAccessToken);
    final refreshToken = await _readOrNull(_secureStorage.getRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('AuthInterceptor: no refresh token');
      await _endSession(SessionEndReason.expired);
      return _RefreshOutcome.sessionEnded;
    }

    try {
      // The backend expects multipart/form-data with a `token` field
      // (FastAPI `Form(...)`), not a JSON body -- sending JSON would
      // silently 422 and break every refresh.
      final response = await _dio.post(
        '/auth/refresh',
        data: FormData.fromMap({'token': refreshToken}),
        options: Options(extra: {'skipAuth': true}),
      );
      final data = response.data;
      final access = data is Map ? data['access_token'] : null;
      final refresh = data is Map ? data['refresh_token'] : null;
      if (access is String &&
          access.isNotEmpty &&
          refresh is String &&
          refresh.isNotEmpty) {
        // Signed out (or in as someone else) while this was in flight --
        // sign-out stops waiting on the server after a few seconds. Saving
        // now would bring the ended session back to life.
        final current = await _readOrNull(_secureStorage.getRefreshToken);
        if (current != refreshToken) {
          debugPrint('AuthInterceptor: session changed during refresh');
          return _RefreshOutcome.unavailable;
        }
        // Both, every time: the server issues a new refresh token on every
        // refresh. The one sent stays good only until the new one is first
        // used; presenting it after that ends the session (SESSION_REUSED).
        await _secureStorage.saveAccessToken(access);
        await _secureStorage.saveRefreshToken(refresh);
        if (replacing != null && replacing.isNotEmpty) {
          _replaced.add('Bearer $replacing');
          while (_replaced.length > _replacedKept) {
            _replaced.remove(_replaced.first);
          }
        }
        debugPrint('AuthInterceptor: token refreshed');
        return _RefreshOutcome.refreshed;
      }
      debugPrint('AuthInterceptor: refresh answered without tokens');
      return _RefreshOutcome.unavailable;
    } on DioException catch (e) {
      // 401 is the server saying the session is over: expired, signed out
      // from the Security page, revoked by a token_version bump, or
      // SESSION_REUSED -- a refresh token older than the last one issued was
      // presented, and the server ended the session. All of them are "your
      // session has ended", said once: the tokens go with it, so no later
      // 401 has a session left to report.
      if (e.response?.statusCode == 401) {
        debugPrint('AuthInterceptor: refresh refused '
            '(${_errorCode(e.response?.data) ?? 'no code'}), session over');
        await _endSession(SessionEndReason.expired);
        return _RefreshOutcome.sessionEnded;
      }
      debugPrint('AuthInterceptor: refresh failed: ${e.type}');
      return _RefreshOutcome.unavailable;
    } catch (e) {
      debugPrint('AuthInterceptor: refresh failed: $e');
      return _RefreshOutcome.unavailable;
    }
  }

  Future<void> _retry(
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final token = await _secureStorage.getAccessToken();
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_retriedKey] = true;
      // A FormData body is consumed by the first send.
      final data = options.data;
      if (data is FormData) options.data = data.clone();

      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (e) {
      debugPrint('AuthInterceptor: retry failed: $e');
      handler.next(DioException(requestOptions: options, error: e));
    }
  }

  /// Delete the tokens and, if there was a session to end, say so.
  ///
  /// A person who never signed in has no tokens; their 401 from a protected
  /// endpoint must not be reported as "your session has ended".
  Future<void> _endSession(SessionEndReason reason) async {
    final hadSession =
        ((await _readOrNull(_secureStorage.getAccessToken)) ?? '').isNotEmpty ||
            ((await _readOrNull(_secureStorage.getRefreshToken)) ?? '')
                .isNotEmpty;
    try {
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
    } catch (e) {
      debugPrint('AuthInterceptor: could not delete tokens: $e');
    }
    if (hadSession) _onSessionEnded(reason);
  }

  /// The original 401, carrying words that fit: the screen that made the
  /// request is about to be replaced by the sign-in screen, and "Could not
  /// validate credentials" is no use to anyone.
  DioException _sessionEnded(DioException err) {
    final read = ApiException.fromResponse(
      err.response?.statusCode,
      err.response?.data,
      originalError: err,
    );
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      message: err.message,
      error: ApiException(
        message: ApiException.sessionEndedMessage,
        statusCode: read.statusCode,
        type: ApiExceptionType.unauthorized,
        originalError: err,
        serverMessage: read.serverMessage,
        errorCode: read.errorCode,
        errors: read.errors,
        fieldErrors: read.fieldErrors,
        trackId: read.trackId,
      ),
    );
  }

  static String? _errorCode(Object? body) {
    final code = body is Map ? body['error_code'] : null;
    return code is String ? code : null;
  }

  static Future<String?> _readOrNull(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (e) {
      debugPrint('AuthInterceptor: could not read token: $e');
      return null;
    }
  }
}

enum _RefreshOutcome { refreshed, sessionEnded, unavailable }
