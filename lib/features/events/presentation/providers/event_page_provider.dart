import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/cache/saved_then_fresh.dart';
import 'package:finnet/features/events/data/datasources/event_page_remote_datasource.dart';

/// What the website's event page shows for the event at [ref] (a slug or
/// an id): speakers, team, contact, seats, the venue's point, and the
/// rails. The copy saved on this phone first, then the server's.
///
/// An error -- a non-public event's 404, no network with nothing saved --
/// is not the page's error: the event page then shows what `/events/info`
/// has, as it always did, so it reads `valueOrNull`.
final eventPageDetailsProvider = StreamProvider.autoDispose
    .family<EventPageDetails?, String>((ref, eventRef) {
  final source = ref.watch(eventPageRemoteDataSourceProvider);
  return savedThenFresh(
    saved: () => source.savedPage(eventRef),
    fresh: () => source.fetchPage(eventRef),
  );
});

/// Whether event [eventId] runs a competition: false when it doesn't, or
/// when that can't be known right now.
final competitionEnabledProvider =
    FutureProvider.autoDispose.family<bool, int>((ref, eventId) async {
  if (eventId <= 0) return false;
  try {
    return await ref
        .watch(eventPageRemoteDataSourceProvider)
        .competitionEnabled(eventId);
  } catch (e) {
    debugPrint('competitionEnabled($eventId): $e');
    return false;
  }
});
