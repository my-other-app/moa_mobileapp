import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/saved_then_fresh.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/clubs/data/datasources/club_page_source.dart';
import 'package:finnet/features/clubs/data/models/club_info.dart';

export 'package:finnet/features/clubs/data/datasources/club_page_source.dart'
    show ClubKey;

/// A club's page: the copy saved on this phone at once when there is one,
/// then the server's. Read again when the person signs in or out, since
/// that changes what can be read (and whether they follow it).
///
/// Shared by the page's header (for its name and share link) and its
/// PROFILE tab, so the two make one request.
final clubInfoProvider =
    StreamProvider.autoDispose.family<ClubInfo, ClubKey>((ref, key) {
  final signedIn = ref.watch(isAuthenticatedProvider);
  final source = ref.watch(clubPageSourceProvider);
  return savedThenFresh(
    saved: () => source.saved(key, signedIn: signedIn),
    fresh: () => source.fresh(key, signedIn: signedIn),
  );
});
