import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/json_read.dart';

/// A club a website address names.
class LinkedClub {
  const LinkedClub({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;
}

/// Looks up what a website address names, for the screens that still take
/// an id: `/events/{slug}` and `/clubs/{slug}` carry slugs, the event and
/// club pages want ids.
///
/// Both lookups use the public `/discover/...` pages the website itself is
/// built from, so an address that works on the site works here, signed in
/// or not. Saved like any shared answer: a link opened before opens again
/// offline.
class LinkTargets {
  LinkTargets(this._dio);

  final Dio _dio;

  /// The id of the event at `/events/{slug}`; null when there is no such
  /// public event. Throws when the server cannot be asked.
  Future<int?> eventId(String slug) async {
    final page = await _page('/discover/events/${Uri.encodeComponent(slug)}');
    return jsonInt(jsonObject(page?['event'])?['id']);
  }

  /// The club at `/clubs/{slug}`; null when there is no such public club.
  /// Throws when the server cannot be asked.
  Future<LinkedClub?> club(String slug) async {
    final page = await _page('/discover/clubs/${Uri.encodeComponent(slug)}');
    final club = jsonObject(page?['club']);
    final id = jsonInt(club?['id']);
    if (id == null) return null;
    return LinkedClub(
      id: id,
      name: jsonText(club?['name']),
      slug: jsonText(club?['slug'], slug),
    );
  }

  Future<Map<String, dynamic>?> _page(String path) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        options: Options(extra: CachePolicy.shared.extra),
      );
      return jsonObject(response.data);
    } catch (e) {
      // Not there (a draft, a deleted event, a typo): say so. Anything else
      // -- offline, the server failing -- is for the screen to offer a retry.
      if (statusCodeOf(e) == 404) return null;
      rethrow;
    }
  }
}

final linkTargetsProvider =
    Provider<LinkTargets>((ref) => LinkTargets(ref.read(dioProvider)));

/// Whether [ref] is a slug the website could have made: words and digits
/// joined by hyphens. Anything else (a file name, a stray path) is not
/// looked up at all.
bool looksLikeSlug(String ref) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,159}$').hasMatch(ref);

/// The id of the public event with [slug] (null: none).
final eventIdForSlugProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, slug) {
  if (!looksLikeSlug(slug)) return Future.value(null);
  return ref.read(linkTargetsProvider).eventId(slug);
});

/// The public club with [slug] (null: none).
final clubForSlugProvider =
    FutureProvider.autoDispose.family<LinkedClub?, String>((ref, slug) {
  if (!looksLikeSlug(slug)) return Future.value(null);
  return ref.read(linkTargetsProvider).club(slug);
});
