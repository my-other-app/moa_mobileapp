import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/notifications/data/datasources/push_settings_remote_datasource.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/features/notifications/presentation/providers/push_settings_provider.dart';
import 'package:finnet/features/notifications/presentation/widgets/push_switches_section.dart';
import 'package:finnet/shared/widgets/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server's switches, answered only when the test says so: the network
/// a test has not let answer is one that has not answered yet.
class _SlowSwitches implements PushSettingsRepository {
  _SlowSwitches({this.saved});

  PushSwitches? saved;
  final checks = <Completer<Result<PushSwitches?>>>[];
  final sets = <Completer<Result<PushSwitches>>>[];
  final sent = <Map<String, bool?>>[];

  @override
  Future<PushSwitches?> savedSwitches() async => saved;

  @override
  Future<Result<PushSwitches?>> switches() {
    final answer = Completer<Result<PushSwitches?>>();
    checks.add(answer);
    return answer.future;
  }

  @override
  Future<Result<PushSwitches>> setSwitches(
      {bool? clubs, bool? topics, bool? platform}) {
    sent.add({'clubs': clubs, 'topics': topics, 'platform': platform});
    final answer = Completer<Result<PushSwitches>>();
    sets.add(answer);
    return answer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _allOn = PushSwitches(clubs: true, topics: true, platform: true);
const _clubsOff = PushSwitches(clubs: false, topics: true, platform: true);
const _savedOnPhone =
    PushSwitches(clubs: false, topics: true, platform: false);

Future<void> _pumpSection(WidgetTester tester, PushSettingsRepository repo) =>
    tester.pumpWidget(ProviderScope(
      overrides: [pushSettingsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PushSwitchesSection())),
      ),
    ));

/// The answer is taken in during one frame; the next draws it.
Future<void> _answered(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

bool _on(WidgetTester tester, String key) =>
    tester.widget<SettingsRow>(find.byKey(ValueKey(key))).value!;

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final answers = <String, Object>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(answers['${options.method} ${options.path}']),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Settings draws the switches without waiting for the network', () {
    testWidgets('the saved switches, before the server has answered',
        (tester) async {
      // The bug: the provider was autoDispose and started empty, and the
      // section was SizedBox.shrink() until GET /notifications/settings
      // answered -- every visit to Settings, "Club Updates" and
      // "Announcements" popped in a round trip late.
      final repo = _SlowSwitches(saved: _savedOnPhone);
      await _pumpSection(tester, repo);
      await tester.pump();

      expect(repo.checks, hasLength(1), reason: 'asked, not yet answered');
      expect(find.text('Club Updates'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(_on(tester, 'push-switch-clubs'), isFalse);
      expect(_on(tester, 'push-switch-platform'), isFalse);
      expect(_on(tester, 'push-switch-topics'), isTrue);
      // A saved copy is shown as it is: no "checking" line under it.
      expect(find.byKey(PushSwitchesSection.checkingKey), findsNothing);

      // The server's answer replaces it.
      repo.checks.single.complete(Either.right(_allOn));
      await _answered(tester);
      expect(_on(tester, 'push-switch-clubs'), isTrue);
      expect(_on(tester, 'push-switch-platform'), isTrue);
    });

    testWidgets('the very first frame has the rows', (tester) async {
      final repo = _SlowSwitches(saved: _savedOnPhone);
      await _pumpSection(tester, repo);

      // Not one pump: no saved copy read yet, no answer -- still rows.
      expect(find.text('Event Notification'), findsOneWidget);
      expect(find.text('Club Updates'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
    });

    testWidgets(
        'first open on a phone: the server\'s defaults, saying they are '
        'being checked', (tester) async {
      final repo = _SlowSwitches();
      await _pumpSection(tester, repo);
      await tester.pump();

      expect(_on(tester, 'push-switch-topics'), isTrue);
      expect(_on(tester, 'push-switch-clubs'), isTrue);
      expect(_on(tester, 'push-switch-platform'), isTrue);
      expect(find.byKey(PushSwitchesSection.checkingKey), findsOneWidget);

      repo.checks.single.complete(Either.right(_clubsOff));
      await _answered(tester);
      expect(_on(tester, 'push-switch-clubs'), isFalse);
      expect(find.byKey(PushSwitchesSection.checkingKey), findsNothing);
    });

    testWidgets('first open and offline: the defaults stay, and say so',
        (tester) async {
      final repo = _SlowSwitches();
      await _pumpSection(tester, repo);
      await tester.pump();

      repo.checks.single.complete(
          Either.left(const NetworkFailure(message: 'No internet')));
      await _answered(tester);

      expect(find.text('Club Updates'), findsOneWidget);
      expect(find.textContaining("Couldn't check these"), findsOneWidget);
    });

    testWidgets('a server that keeps no switches shows none', (tester) async {
      final repo = _SlowSwitches();
      await _pumpSection(tester, repo);
      repo.checks.single.complete(Either.right(null));
      await tester.pump();
      await tester.pump();

      expect(find.text('Club Updates'), findsNothing);
    });
  });

  group('turning one', () {
    testWidgets('moves at once, and goes back with a message if refused',
        (tester) async {
      final repo = _SlowSwitches(saved: _allOn);
      await _pumpSection(tester, repo);
      await tester.pump();
      repo.checks.single.complete(Either.right(_allOn));
      await tester.pump();

      await tester.tap(find.text('Club Updates'));
      await tester.pump();
      expect(_on(tester, 'push-switch-clubs'), isFalse, reason: 'at once');
      expect(repo.sent, [
        {'clubs': false, 'topics': null, 'platform': null}
      ]);

      repo.sets.single
          .complete(Either.left(const NetworkFailure(message: 'offline')));
      await tester.pump();
      await tester.pump();

      expect(_on(tester, 'push-switch-clubs'), isTrue, reason: 'put back');
      expect(find.textContaining("You're offline, so that wasn't changed"),
          findsOneWidget);
    });

    testWidgets('a server error says to try again', (tester) async {
      final repo = _SlowSwitches(saved: _allOn);
      await _pumpSection(tester, repo);
      await tester.pump();

      await tester.tap(find.text('Announcements'));
      await tester.pump();
      repo.sets.single
          .complete(Either.left(const ServerFailure(message: 'boom')));
      await tester.pump();
      await tester.pump();

      expect(_on(tester, 'push-switch-platform'), isTrue);
      expect(find.text("Couldn't change that. Try again in a moment."),
          findsOneWidget);
    });

    test('a refusal puts back only the switch it was about', () async {
      final repo = _SlowSwitches(saved: _allOn);
      final container = ProviderContainer(overrides: [
        pushSettingsRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(pushSwitchesProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final clubs = notifier.set(clubs: false);
      final platform = notifier.set(platform: false);
      expect(container.read(pushSwitchesProvider).switches,
          const PushSwitches(clubs: false, topics: true, platform: false));

      repo.sets[0].complete(Either.left(const ServerFailure(message: 'no')));
      expect(await clubs, isNotNull);
      expect(container.read(pushSwitchesProvider).switches,
          const PushSwitches(clubs: true, topics: true, platform: false));

      repo.sets[1].complete(Either.right(
          const PushSwitches(clubs: true, topics: true, platform: false)));
      expect(await platform, isNull);
      expect(container.read(pushSwitchesProvider).checked, isTrue);
    });

    test('an answer to a check sent before the change does not undo it',
        () async {
      final repo = _SlowSwitches(saved: _allOn);
      final container = ProviderContainer(overrides: [
        pushSettingsRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(pushSwitchesProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final change = notifier.set(clubs: false);
      // The check that left before the change comes back with clubs on.
      repo.checks.single.complete(Either.right(_allOn));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(pushSwitchesProvider).switches?.clubs, isFalse);

      repo.sets.single.complete(Either.right(_clubsOff));
      await change;
      expect(container.read(pushSwitchesProvider).switches, _clubsOff);
    });

    test('lives for the session: reopening Settings asks nothing new', () async {
      final repo = _SlowSwitches(saved: _allOn);
      final container = ProviderContainer(overrides: [
        pushSettingsRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final first = container.listen(pushSwitchesProvider, (_, __) {});
      repo.checks.single.complete(Either.right(_clubsOff));
      await Future<void>.delayed(Duration.zero);
      first.close();
      await Future<void>.delayed(Duration.zero);

      // Settings closed and opened again: the answer is still there.
      expect(container.read(pushSwitchesProvider).switches, _clubsOff);
      expect(repo.checks, hasLength(1));
    });
  });

  group('the saved copy', () {
    late _Adapter adapter;
    late ApiCache cache;
    late PushSettingsRemoteDataSourceImpl remote;

    setUp(() {
      adapter = _Adapter();
      cache = ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiCacheInterceptor(cache));
      remote = PushSettingsRemoteDataSourceImpl(dio, cache: cache);
    });

    test('the server\'s answer is kept, encrypted, never pruned for room',
        () async {
      adapter.answers['GET /notifications/settings'] = {
        'clubs': false,
        'topics': true,
        'platform': true,
      };

      expect(await remote.savedSwitches(), isNull);
      await remote.switches();

      expect(CachePolicy.of(adapter.requests.single), CachePolicy.personalKept);
      expect(await remote.savedSwitches(), _clubsOff);
    });

    test('a change the server confirmed is what the next Settings opens on',
        () async {
      adapter.answers['GET /notifications/settings'] = {
        'clubs': true,
        'topics': true,
        'platform': true,
      };
      await remote.switches();
      adapter.answers['PATCH /notifications/settings'] = {
        'clubs': false,
        'topics': true,
        'platform': true,
      };

      await remote.setSwitches({'clubs': false});

      expect(await remote.savedSwitches(), _clubsOff);
    });

    test('nothing saved survives a sign-out', () async {
      adapter.answers['GET /notifications/settings'] = {'clubs': false};
      await remote.switches();
      await cache.clear();

      expect(await remote.savedSwitches(), isNull);
    });
  });
}
