import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/saved_then_fresh.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/domain/repositories/discover_repository.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:finnet/features/discover/presentation/providers/paged_list.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart'
    show ThreadInteractions;
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';

T _orThrow<T>(Result<T> result) =>
    result.fold((failure) => throw failure, (value) => value);

/// The place a list made now is about ([discoverPlaceProvider]); the list
/// is made again when the person changes it.
DiscoverWhere? _placeFor(Ref ref) {
  ref.watch(discoverPlaceProvider.select((s) => s.changes));
  return ref.read(discoverPlaceProvider).place;
}

/// The copy saved for [at]. Else, the one saved before the place was kept
/// -- asked without a point, the launch that guessed it -- if the server
/// put that one at the same place; never another place's.
Future<T?> _savedFor<T>(
  DiscoverPoint? at,
  Future<T?> Function(DiscoverPoint? at) read,
  DiscoverWhere Function(T copy) whereOf,
) async {
  final copy = await read(at);
  if (copy != null || at == null) return copy;
  final before = await read(null);
  return before != null && whereOf(before).point == at ? before : null;
}

// --- The front page -----------------------------------------------------------

/// `/discover/home` about the kept place: the saved copy first, then the
/// server's. With no place yet, the server places the connection and that
/// guess is kept. A failure with nothing saved is the provider's error, for
/// the screen to offer a retry (`ref.invalidate`). Read again when the app
/// comes back online.
final discoverHomeProvider = StreamProvider<DiscoverHome>((ref) {
  ref.watch(backOnlineProvider);
  final repository = ref.watch(discoverRepositoryProvider);
  final place = _placeFor(ref);
  final places = ref.read(discoverPlaceProvider.notifier);
  final at = place?.point;
  return savedThenFresh(
    saved: () async {
      final copy = await _savedFor(
          at, (at) => repository.savedHome(at: at), (h) => h.where);
      return copy?.about(place);
    },
    fresh: () async {
      final home = _orThrow(await repository.home(at: at));
      if (place == null) places.guessed(home.where);
      return home.about(place);
    },
  );
});

/// Events from the clubs the person follows, for a rail on the front page:
/// the first page of the FOLLOWING tab (saved with it). Empty signed out --
/// nothing is asked.
final followingRailProvider =
    StreamProvider.autoDispose<List<DiscoverEvent>>((ref) {
  if (!ref.watch(isAuthenticatedProvider)) return Stream.value(const []);
  ref.watch(backOnlineProvider);
  final repository = ref.watch(discoverRepositoryProvider);
  return savedThenFresh(
    saved: repository.savedFollowingEvents,
    fresh: () async => _orThrow(await repository.followingEvents()),
  );
});

// --- Find events ----------------------------------------------------------------

typedef EventSearchState = PagedState<DiscoverEvent, EventResults>;

/// The events matching a set of filters, a page at a time, about the kept
/// place. One per set: changing a filter starts a fresh list, and going
/// back to a screen finds its list as it was. Its first page is read again
/// when the app comes back online.
final eventSearchProvider = StateNotifierProvider.autoDispose
    .family<EventSearchNotifier, EventSearchState, EventFilters>(
        (ref, filters) {
  final notifier = EventSearchNotifier(
    ref.watch(discoverRepositoryProvider),
    filters,
    place: _placeFor(ref),
    onGuess: ref.read(discoverPlaceProvider.notifier).guessed,
  )..load();
  refreshWhenBackOnline(ref, notifier);
  return notifier;
});

class EventSearchNotifier extends PagedNotifier<DiscoverEvent, EventResults> {
  EventSearchNotifier(this._repository, EventFilters filters,
      {this.place, this.onGuess})
      : filters = filters.normalized();

  final DiscoverRepository _repository;
  final EventFilters filters;

  /// The place every page is asked about, the same for all of them; null
  /// for the server to place the connection.
  final DiscoverWhere? place;

  /// Told where the server placed the connection, when [place] is null.
  final void Function(DiscoverWhere)? onGuess;

  @override
  Future<Result<PageWithMeta<DiscoverEvent, EventResults>>> fetchPage(
      PageRequest page) async {
    final result =
        await _repository.events(filters, page, at: place?.point);
    return result.map((r) {
      if (place == null) onGuess?.call(r.where);
      return (r.page, r.about(place));
    });
  }

  @override
  Future<PageWithMeta<DiscoverEvent, EventResults>?> savedFirstPage() async {
    final saved = await _savedFor(place?.point,
        (at) => _repository.savedEvents(filters, at: at), (r) => r.where);
    return saved == null ? null : (saved.page, saved.about(place));
  }

  @override
  Object keyOf(DiscoverEvent item) => item.id;
}

/// One month of the calendar: how many events each day has, with the
/// list's filters.
typedef CalendarKey = ({EventFilters filters, String month});

final calendarMonthProvider =
    StreamProvider.autoDispose.family<CalendarMonth, CalendarKey>((ref, key) {
  ref.watch(backOnlineProvider);
  final repository = ref.watch(discoverRepositoryProvider);
  final filters = key.filters.normalized();
  final at = _placeFor(ref)?.point;
  return savedThenFresh(
    saved: () => repository.savedCalendar(filters, key.month, at: at),
    fresh: () async =>
        _orThrow(await repository.calendar(filters, key.month, at: at)),
  );
});

// --- Clubs ----------------------------------------------------------------------

typedef ClubSearchState = PagedState<DiscoverClub, ClubResults>;

/// The clubs matching a set of filters, about the kept place, as
/// [eventSearchProvider].
final clubSearchProvider = StateNotifierProvider.autoDispose
    .family<ClubSearchNotifier, ClubSearchState, ClubFilters>((ref, filters) {
  final notifier = ClubSearchNotifier(
    ref.watch(discoverRepositoryProvider),
    filters,
    place: _placeFor(ref),
    onGuess: ref.read(discoverPlaceProvider.notifier).guessed,
  )..load();
  refreshWhenBackOnline(ref, notifier);
  return notifier;
});

class ClubSearchNotifier extends PagedNotifier<DiscoverClub, ClubResults> {
  ClubSearchNotifier(this._repository, ClubFilters filters,
      {this.place, this.onGuess})
      : filters = filters.normalized();

  final DiscoverRepository _repository;
  final ClubFilters filters;

  /// As [EventSearchNotifier.place].
  final DiscoverWhere? place;
  final void Function(DiscoverWhere)? onGuess;

  @override
  Future<Result<PageWithMeta<DiscoverClub, ClubResults>>> fetchPage(
      PageRequest page) async {
    final result = await _repository.clubs(filters, page, at: place?.point);
    return result.map((r) {
      if (place == null) onGuess?.call(r.where);
      return (r.page, r.about(place));
    });
  }

  @override
  Future<PageWithMeta<DiscoverClub, ClubResults>?> savedFirstPage() async {
    final saved = await _savedFor(place?.point,
        (at) => _repository.savedClubs(filters, at: at), (r) => r.where);
    return saved == null ? null : (saved.page, saved.about(place));
  }

  @override
  Object keyOf(DiscoverClub item) => item.slug ?? item.id;
}

// --- Every club's posts ---------------------------------------------------------

typedef ThreadsFeedState = PagedState<Thread, Object?>;

/// Every club's newest posts (`/discover/threads`), with likes and votes.
final discoverThreadsProvider = StateNotifierProvider.autoDispose<
    DiscoverThreadsNotifier, ThreadsFeedState>((ref) {
  final notifier = DiscoverThreadsNotifier(
    ref.watch(discoverRepositoryProvider),
    ref.watch(threadRepositoryProvider),
  )..load();
  refreshWhenBackOnline(ref, notifier);
  return notifier;
});

class DiscoverThreadsNotifier extends PagedNotifier<Thread, Object?>
    with ThreadInteractions<ThreadsFeedState> {
  DiscoverThreadsNotifier(this._discover, this.repository);

  final DiscoverRepository _discover;

  @override
  final ThreadRepository repository;

  @override
  Future<Result<PageWithMeta<Thread, Object?>>> fetchPage(
      PageRequest page) async {
    final result = await _discover.threads(page);
    return result.map((p) => (p, null));
  }

  @override
  Future<PageWithMeta<Thread, Object?>?> savedFirstPage() async {
    final saved = await _discover.savedThreads();
    return saved == null ? null : (saved, null);
  }

  @override
  Object keyOf(Thread item) => item.id;

  /// Read [threadId] again -- back from its page, where it may have been
  /// liked, voted on, commented on or removed -- so its card says so.
  Future<void> reread(String threadId) async {
    final result = await repository.getThread(threadId);
    if (!mounted) return;
    result.fold(
      (failure) {
        if (failure.code == '404') removeItem(threadId);
      },
      replaceItem,
    );
  }

  @override
  Thread? findThread(String threadId) => itemWithKey(threadId);

  @override
  void putThread(Thread thread) => replaceItem(thread);
}

// --- A topic --------------------------------------------------------------------

/// One topic by slug: `/interests/topics/{slug}` (saved first), else the
/// one the topics directory has by that slug -- a server without the route,
/// or one that cannot be reached right now. Null when there is no such
/// topic anywhere.
final topicPageProvider =
    StreamProvider.autoDispose.family<Topic?, String>((ref, slug) {
  ref.watch(backOnlineProvider);
  final repository = ref.watch(discoverRepositoryProvider);
  final key = slug.trim().toLowerCase();

  Future<Topic?> fromDirectory(Failure failure) async {
    try {
      final topics = await ref.read(topicDirectoryProvider.future);
      final found = topicNamed(key, topics);
      if (found != null || failure.code == '404') return found;
    } catch (_) {
      if (failure.code == '404') return null;
    }
    throw failure;
  }

  return savedThenFresh<Topic?>(
    saved: () => repository.savedTopic(key),
    fresh: () async {
      final result = await repository.topic(key);
      return result.isRight ? result.right : fromDirectory(result.left);
    },
  );
});
