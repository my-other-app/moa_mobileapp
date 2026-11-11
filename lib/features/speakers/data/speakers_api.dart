import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/speakers/domain/speaker.dart';

final speakersApiProvider = Provider<SpeakersApi>((ref) => SpeakersApi());

/// The speakers directory's public side (feature-register
/// `speakers-contract.md`): a speaker's page and following them, through
/// the app's one client -- signed in, the session goes with the page, so
/// it says whether they follow the speaker.
class SpeakersApi {
  SpeakersApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  static String path(String slug) => '/speakers/${Uri.encodeComponent(slug)}';

  /// A speaker's page; [SpeakerMoved] for a merged one, [SpeakerMissing]
  /// for a hidden one, one that never was, or a server without speaker
  /// pages (404 all three).
  Future<SpeakerLookup> profile(String slug) async {
    try {
      final res = await _client.request(path(slug), DioMethod.get);
      final moved = redirectSlugIn(res.data);
      if (moved != null && moved != slug) return SpeakerMoved(moved);
      return SpeakerFound(SpeakerProfile.fromJson(res.data, slug: slug));
    } catch (e) {
      // A merged profile answered as a redirect the client did not follow
      // (a 301 with the new slug in its body).
      final moved = redirectSlugIn(_bodyOf(e));
      if (moved != null && moved != slug) return SpeakerMoved(moved);
      if (statusCodeOf(e) == 404 || statusCodeOf(e) == 410) {
        return const SpeakerMissing();
      }
      rethrow;
    }
  }

  static Object? _bodyOf(Object error) {
    final api = apiExceptionOf(error);
    final dio = api?.originalError ?? error;
    return dio is DioException ? dio.response?.data : null;
  }

  Future<void> follow(String slug) async {
    await _client.request('${path(slug)}/follow', DioMethod.post);
  }

  Future<void> unfollow(String slug) async {
    await _client.request('${path(slug)}/follow', DioMethod.delete);
  }
}
