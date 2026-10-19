import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/domain/repositories/discover_repository.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepositoryImpl(ref.watch(discoverRemoteDataSourceProvider));
});

class DiscoverRepositoryImpl implements DiscoverRepository {
  DiscoverRepositoryImpl(this._remote);

  final DiscoverRemoteDataSource _remote;

  Future<Result<T>> _guard<T>(String name, Future<T> Function() call) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('DiscoverRepository.$name error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  /// A saved copy that cannot be read counts as none.
  Future<T?> _saved<T>(String name, Future<T?> Function() call) async {
    try {
      return await call();
    } catch (e) {
      debugPrint('DiscoverRepository.$name: no saved copy: $e');
      return null;
    }
  }

  @override
  Future<Result<DiscoverHome>> home() => _guard('home', _remote.home);

  @override
  Future<DiscoverHome?> savedHome() => _saved('savedHome', _remote.savedHome);

  @override
  Future<Result<EventResults>> events(EventFilters filters, PageRequest page) =>
      _guard('events', () => _remote.events(filters, page));

  @override
  Future<EventResults?> savedEvents(EventFilters filters) =>
      _saved('savedEvents', () => _remote.savedEvents(filters));

  @override
  Future<Result<CalendarMonth>> calendar(EventFilters filters, String month) =>
      _guard('calendar', () => _remote.calendar(filters, month));

  @override
  Future<CalendarMonth?> savedCalendar(EventFilters filters, String month) =>
      _saved('savedCalendar', () => _remote.savedCalendar(filters, month));

  @override
  Future<Result<ClubResults>> clubs(ClubFilters filters, PageRequest page) =>
      _guard('clubs', () => _remote.clubs(filters, page));

  @override
  Future<ClubResults?> savedClubs(ClubFilters filters) =>
      _saved('savedClubs', () => _remote.savedClubs(filters));

  @override
  Future<Result<DiscoverPage<Thread>>> threads(PageRequest page) =>
      _guard('threads', () => _remote.threads(page));

  @override
  Future<DiscoverPage<Thread>?> savedThreads() =>
      _saved('savedThreads', _remote.savedThreads);

  @override
  Future<Result<Topic>> topic(String slug) =>
      _guard('topic', () => _remote.topic(slug));

  @override
  Future<Topic?> savedTopic(String slug) =>
      _saved('savedTopic', () => _remote.savedTopic(slug));

  @override
  Future<Result<List<DiscoverEvent>>> followingEvents({int limit = 10}) =>
      _guard('followingEvents', () => _remote.followingEvents(limit: limit));

  @override
  Future<List<DiscoverEvent>?> savedFollowingEvents({int limit = 10}) =>
      _saved('savedFollowingEvents',
          () => _remote.savedFollowingEvents(limit: limit));
}
