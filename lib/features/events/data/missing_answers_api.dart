import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/domain/missing_answers.dart';

final missingAnswersApiProvider =
    Provider<MissingAnswersApi>((ref) => MissingAnswersApi());

/// A person's asked-for details (feature-register
/// `missing-answers-contract.md` §2.3): `GET` and `POST
/// /events/{event_id}/answers/{ref}?k=…`, through the app's one client, so
/// a refusal arrives as an `ApiException` with its `error_code` and field
/// `errors`.
///
/// The link's key (`k`) is the proof, so no session goes with it -- the
/// link works for whoever it was sent to, signed in or not. Without a key
/// the signed-in person's own token goes instead, which the server accepts
/// for their own registration or request. Nothing is saved on the phone:
/// it is a personal page.
class MissingAnswersApi {
  MissingAnswersApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  static String path(int eventId, String ref) =>
      '/events/$eventId/answers/${Uri.encodeComponent(ref)}';

  Future<AnswersForm> fetch(int eventId, String ref, {String key = ''}) async {
    final res = await _client.request(
      path(eventId, ref),
      DioMethod.get,
      param: key.isEmpty ? null : {'k': key},
      skipAuth: key.isNotEmpty,
    );
    return AnswersForm.fromJson(res.data, fallbackEventId: eventId);
  }

  /// [answers] sent: the screen as the server now sees it (the same shape
  /// as [fetch]).
  Future<AnswersForm> submit(
    int eventId,
    String ref,
    Map<String, Object?> answers, {
    String key = '',
  }) async {
    final res = await _client.request(
      path(eventId, ref),
      DioMethod.post,
      param: {'answers': answers},
      query: key.isEmpty ? null : {'k': key},
      skipAuth: key.isNotEmpty,
    );
    return AnswersForm.fromJson(res.data, fallbackEventId: eventId);
  }
}
