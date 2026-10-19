import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/saved_then_fresh.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/domain/repositories/discover_repository.dart';
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

// --- The front page -----------------------------------------------------------

/// `/discover/home`: the saved copy first, then the server's. A failure with
/// nothing saved is the provider's error, for the screen to offer a retry
/// (`ref.invalidate`).
final discoverHomeProvider = StreamProvider<DiscoverHome>((ref) {
  final repository = ref.watch(discoverRepositoryProvider);
  return savedThenFresh(
    saved: repository.savedHome,
    fresh: () async => _orThrow(await repository.home()),
  );
});

/// Events from the clubs the person follows, for a rail on the front page:
/// the first page of the FOLLOWING tab (saved with it). Empty signed out --
/// nothing is asked.
final followingRailProvider =
    StreamProvider.autoDispose<List<DiscoverEvent>>((ref) {
  if (!ref.watch(isAuthenticatedProvider)) return Stream.value(const []);
  final repository = ref.watch(discoverRepositoryProvider);
  return savedThenFresh(
    saved: repository.savedFollowingEvents,
    fresh: () async => _orThrow(await repository.followingEvents()),
  );
});

// --- Find events ----------------------------------------------------------------

typedef EventSearchState = PagedState<DiscoverEvent, EventResults>;

/// The events matching a set of filters, a page at a time. One per set:
/// changing a filter starts a fresh list, and going back to a screen finds
/// its list as it was.
final eventSearchProvider = StateNotifierProvider.autoDispose
    .family<EventSearchNotifier, EventSearchState, EventFilters>(
        (ref, filters) {
  return EventSearchNotifier(ref.watch(discoverRepositoryProvider), filters)
    ..load();
});

class EventSearchNotifier extends PagedNotifier<DiscoverEvent, EventResults> {
  EventSearchNotifier(this._repository, EventFilters filters)
      : filters = filters.normalized();

  final DiscoverRepository _repository;
  final EventFilters filters;

  @override
  Future<Result<PageWithMeta<DiscoverEvent, EventResults>>> fetchPage(
      PageRequest page) async {
    final result = await _repository.events(filters, page);
    return result.map((r) => (r.page, r));
  }

  @override
  Future<PageWithMeta<DiscoverEvent, EventResults>?> savedFirstPage() async {
    final saved = await _repository.savedEvents(filters);
    return saved == null ? null : (saved.page, saved);
  }

  @override
  Object keyOf(DiscoverEvent item) => item.id;
}

/// One month of the calendar: how many events each day has, with the
/// list's filters.
typedef CalendarKey = ({EventFilters filters, String month});

final calendarMonthProvider =
    StreamProvider.autoDispose.family<CalendarMonth, CalendarKey>((ref, key) {
  final repository = ref.watch(discoverRepositoryProvider);
  final filters = key.filters.normalized();
  return savedThenFresh(
    saved: () => repository.savedCalendar(filters, key.month),
    fresh: () async => _orThrow(await repository.calendar(filters, key.month)),
  );
});

// --- Clubs ----------------------------------------------------------------------

typedef ClubSearchState = PagedState<DiscoverClub, ClubResults>;

final clubSearchProvider = StateNotifierProvider.autoDispose
    .family<ClubSearchNotifier, ClubSearchState, ClubFilters>((ref, filters) {
  return ClubSearchNotifier(ref.watch(discoverRepositoryProvider), filters)
    ..load();
});

class ClubSearchNotifier extends PagedNotifier<DiscoverClub, ClubResults> {
  ClubSearchNotifier(this._repository, ClubFilters filters)
      : filters = filters.normalized();

  final DiscoverRepository _repository;
  final ClubFilters filters;

  @override
  Future<Result<PageWithMeta<DiscoverClub, ClubResults>>> fetchPage(
      PageRequest page) async {
    final result = await _repository.clubs(filters, page);
    return result.map((r) => (r.page, r));
  }

  @override
  Future<PageWithMeta<DiscoverClub, ClubResults>?> savedFirstPage() async {
    final saved = await _repository.savedClubs(filters);
    return saved == null ? null : (saved.page, saved);
  }

  @override
  Object keyOf(DiscoverClub item) => item.slug ?? item.id;
}

// --- Every club's posts ---------------------------------------------------------

typedef ThreadsFeedState = PagedState<Thread, Object?>;

/// Every club's newest posts (`/discover/threads`), with likes and votes.
final discoverThreadsProvider =
    StateNotifierProvider.autoDispose<DiscoverThreadsNotifier, ThreadsFeedState>(
        (ref) {
  return DiscoverThreadsNotifier(
    ref.watch(discoverRepositoryProvider),
    ref.watch(threadRepositoryProvider),
  )..load();
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
