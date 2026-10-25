import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/clubs/data/models/club_info.dart';

/// Which club a page is about: its id, and its slug when the way in knew it
/// (a discover card, an event page, a link to `myotherapp.in/clubs/{slug}`).
@immutable
class ClubKey {
  final int id;
  final String slug;

  const ClubKey(this.id, [this.slug = '']);

  @override
  bool operator ==(Object other) =>
      other is ClubKey && other.id == id && other.slug == slug;

  @override
  int get hashCode => Object.hash(id, slug);

  @override
  String toString() => 'ClubKey($id, $slug)';
}

final clubPageSourceProvider = Provider<ClubPageSource>((ref) {
  return ClubPageSource(ref.watch(dioProvider),
      cache: ref.watch(apiCacheProvider));
});

/// A club's page, from the server or as last saved on this phone.
///
/// Signed in, it is `GET /clubs/info/{id}`, which knows whether you follow
/// the club. Signed out, that answers 401, so it is the public page the
/// website shows, `GET /discover/clubs/{slug}` -- which needs the slug.
/// Signed out with no slug, `/clubs/info/{id}` is tried all the same, and
/// its 401 is what the page turns into "sign in to see this club".
class ClubPageSource {
  ClubPageSource(this._dio, {ApiCache? cache}) : _cache = cache;

  final Dio _dio;
  final ApiCache? _cache;

  static String infoPath(int id) => '/clubs/info/$id';

  static String publicPath(String slug) =>
      '/discover/clubs/${Uri.encodeComponent(slug)}';

  /// Whether [key] is read from the public page rather than the club detail.
  static bool readsPublicPage(ClubKey key, {required bool signedIn}) =>
      key.slug.isNotEmpty && (!signedIn || key.id <= 0);

  Future<ClubInfo?> saved(ClubKey key, {required bool signedIn}) async {
    final public = readsPublicPage(key, signedIn: signedIn);
    final data = await (_cache ?? ApiCache.instance).savedAnswer(
      _dio,
      public ? publicPath(key.slug) : infoPath(key.id),
    );
    if (data is! Map) return null;
    final json = Map<String, dynamic>.from(data);
    return public ? ClubInfo.fromDiscoverJson(json) : ClubInfo.fromJson(json);
  }

  Future<ClubInfo> fresh(ClubKey key, {required bool signedIn}) async {
    if (!readsPublicPage(key, signedIn: signedIn)) {
      return ClubInfo.fromJson(await _get(infoPath(key.id), signedIn));
    }
    final public =
        ClubInfo.fromDiscoverJson(await _get(publicPath(key.slug), signedIn));
    // Signed in from a link that knew only the slug: the public page found
    // the club; the detail says whether this person follows it.
    if (signedIn && public.id > 0) {
      final info = ClubInfo.fromJson(await _get(infoPath(public.id), true));
      return info.withPublicFacts(public);
    }
    return public;
  }

  Future<Map<String, dynamic>> _get(String path, bool signedIn) async {
    final response = await _dio.get<dynamic>(
      path,
      options: Options(extra: {
        ...CachePolicy.shared.extra,
        // Signed out there is no session to send or renew: a 401 is the
        // answer, not a reason to try a refresh that cannot happen.
        if (!signedIn) 'skipAuth': true,
      }),
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}

extension on ClubInfo {
  /// This club, with what only its public page says.
  ClubInfo withPublicFacts(ClubInfo public) => ClubInfo(
        id: id,
        name: name,
        slug: slug.isEmpty ? public.slug : slug,
        logo: logo,
        coverUrl: coverUrl ?? public.coverUrl,
        tagline: tagline.isEmpty ? public.tagline : tagline,
        locationName: locationName,
        locationLink: locationLink,
        about: about,
        rating: rating,
        totalRatings: totalRatings,
        socials: socials,
        interests: interests,
        topics: topics,
        followersCount: followersCount,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        userData: userData,
        org: org,
        team: team.isEmpty ? public.team : team,
        partners: partners.isEmpty ? public.partners : partners,
        websiteUrl: public.websiteUrl,
        eventsHeld: public.eventsHeld,
        whatsappUpdates: whatsappUpdates,
      );
}
