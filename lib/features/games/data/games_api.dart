import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/services/crash_reporting.dart';
import 'package:finnet/features/games/domain/games.dart';

final gamesApiProvider = Provider<GamesApi>((ref) => GamesApi());

/// The games' two calls (`games/CONTRACT.md` §3), through the app's one
/// client.
class GamesApi {
  GamesApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  /// Which games the event has on. No games for a 404, an answer of an
  /// unknown shape, or an event the server could not be asked about; the
  /// card is kept on the phone, so a saved one still shows offline.
  Future<EventGames> fetchPublic(int eventId) async {
    try {
      final res = await _client.request(
        '/games/$eventId/public',
        DioMethod.get,
        // Signed in, so the server can say whether this person can play.
        cache: CachePolicy.personal,
      );
      return EventGames.fromJson(res.data);
    } catch (e) {
      debugPrint(redactForCrashReport('games public($eventId): $e'));
      return EventGames.none;
    }
  }

  /// A session for the signed-in person's registration. Refusals
  /// (`NOT_CHECKED_IN`, `PLAN_FEATURE_REQUIRED`, offline...) arrive as the
  /// client's usual [ApiException]; an answer without a token is one too.
  Future<GameSession> createSession(int eventId) async {
    final res = await _client.request(
      '/games/$eventId/session',
      DioMethod.post,
    );
    final session = GameSession.fromJson(res.data);
    if (session == null) {
      throw const ApiException(
        message: ApiException.genericMessage,
        type: ApiExceptionType.unknown,
      );
    }
    return session;
  }
}
