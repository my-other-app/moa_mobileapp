/// Centralized API endpoints for the application.
///
/// Using an enum-based approach for type-safe endpoint management.
enum ApiEndpoint {
  // Auth endpoints
  googleSignIn('/auth/google'),
  logout('/auth/logout'),
  refreshToken('/auth/refresh'),

  // User & Profile endpoints
  getProfile('/user/profile/me'),
  updateProfile('/user/profile'),

  // Clubs endpoints
  clubsList('/clubs/list'),
  clubDetails('/clubs'),
  followClub('/clubs/follow'),
  unfollowClub('/clubs/unfollow'),
  pinClub('/clubs/pin'),
  unpinClub('/clubs/unpin'),

  // Events endpoints
  eventsList('/events/list'),
  eventDetails('/events'),
  registerEvent('/events/register'),

  // Interests endpoints
  interestsList('/interests/list'),
  updateInterests('/user/interests'),

  // Organizations endpoints
  organizationsList('/organizations/list'),

  // Avatars endpoints
  avatarsList('/avatars/list');

  final String path;

  const ApiEndpoint(this.path);

  /// Get the full endpoint path with optional ID.
  String withId(dynamic id) => '$path/$id';

  /// Get the full endpoint path with query parameters.
  String withQuery(Map<String, dynamic> params) {
    if (params.isEmpty) return path;

    final queryString = params.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    return '$path?$queryString';
  }
}
