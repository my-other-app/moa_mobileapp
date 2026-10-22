// The offline cue and coming back: one strip for the whole app, a calm
// offline state for a screen never opened while online -- which reads
// itself again when the network returns -- and the screens on show brought
// up to date the moment it does.

import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/domain/repositories/discover_repository.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts what is asked; answers [home] and a page of events.
class _Discover implements DiscoverRepository {
  int homes = 0;
  int eventPages = 0;
  String city = 'Kochi';

  @override
  Future<DiscoverHome?> savedHome({DiscoverPoint? at}) async => null;

  @override
  Future<Result<DiscoverHome>> home({DiscoverPoint? at}) async {
    homes++;
    return Either.right(DiscoverHome(where: DiscoverWhere(city: city)));
  }

  @override
  Future<EventResults?> savedEvents(EventFilters filters,
          {DiscoverPoint? at}) async =>
      null;

  @override
  Future<Result<EventResults>> events(EventFilters filters, PageRequest page,
      {DiscoverPoint? at}) async {
    eventPages++;
    return Either.right(const EventResults());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  late NetworkStatus status;

  setUp(() => status = NetworkStatus(probe: () async => false));
  tearDown(() => status.reportOnline());

  group('ErrorView', () {
    const network = ApiException(
      message: ApiException.networkMessage,
      type: ApiExceptionType.network,
    );

    testWidgets('a network failure is the offline state, not an error',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ErrorView(exception: network, onRetry: () {}, status: status),
      ));

      expect(find.byKey(ErrorView.offlineKey), findsOneWidget);
      expect(find.text(ErrorView.offlineTitle), findsOneWidget);
      expect(find.text(ErrorView.offlineMessage), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets("the message a screen passes for one reads the same",
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ErrorView(
          message: ApiException.networkMessage,
          onRetry: () {},
          status: status,
        ),
      ));
      expect(find.byKey(ErrorView.offlineKey), findsOneWidget);
    });

    testWidgets('it reads the screen again by itself when back online',
        (tester) async {
      var retried = 0;
      status.reportOffline();
      await tester.pumpWidget(MaterialApp(
        home: ErrorView(
          exception: network,
          onRetry: () => retried++,
          status: status,
        ),
      ));
      expect(retried, 0);

      status.reportOnline();
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('a vague failure while the app knows it is offline is the '
        'offline state too', (tester) async {
      status.reportOffline();
      await tester.pumpWidget(MaterialApp(
        home: ErrorView(message: "Couldn't load what's on.", status: status),
      ));
      expect(find.byKey(ErrorView.offlineKey), findsOneWidget);

      // Back online, it is an ordinary failure again.
      status.reportOnline();
      await tester.pump();
      expect(find.byKey(ErrorView.offlineKey), findsNothing);
    });

    testWidgets('the server refusing is still an error, and is not retried '
        'by itself', (tester) async {
      var retried = 0;
      await tester.pumpWidget(MaterialApp(
        home: ErrorView(
          message: 'Club not found',
          exception: const ApiException(
              message: 'Club not found', type: ApiExceptionType.notFound),
          onRetry: () => retried++,
          status: status,
        ),
      ));
      expect(find.byKey(ErrorView.offlineKey), findsNothing);
      expect(find.text('Not Found'), findsOneWidget);

      status.reportOffline();
      status.reportOnline();
      await tester.pump();
      expect(retried, 0);
    });

    testWidgets('compact, offline', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorView(
            compact: true,
            exception: network,
            onRetry: () {},
            status: status,
          ),
        ),
      ));
      expect(find.text(ErrorView.compactOfflineMessage), findsOneWidget);
    });
  });

  group('OfflineBanner', () {
    testWidgets("one slim strip: \"You're offline, showing what's saved\"",
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) =>
            OfflineBanner(status: status, child: child!),
        home: const Scaffold(body: Text('page')),
      ));
      expect(find.byKey(OfflineBanner.stripKey), findsNothing);

      status.reportOffline();
      await tester.pumpAndSettle();
      expect(find.byKey(OfflineBanner.stripKey), findsOneWidget);
      expect(find.text("You're offline, showing what's saved"), findsOneWidget);
      expect(find.text('page'), findsOneWidget);
      expect(tester.getSize(find.byKey(OfflineBanner.stripKey)).height,
          lessThan(40), reason: 'slim: not a banner that takes the screen');

      status.reportOnline();
      await tester.pumpAndSettle();
      expect(find.byKey(OfflineBanner.stripKey), findsNothing);
    });
  });

  group('back online, what is on show is read again', () {
    ProviderContainer container(_Discover discover) {
      final c = ProviderContainer(overrides: [
        networkStatusProvider.overrideWithValue(status),
        discoverRepositoryProvider.overrideWithValue(discover),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('DISCOVER', () async {
      final discover = _Discover();
      final c = container(discover);
      final sub = c.listen(discoverHomeProvider, (_, __) {});
      addTearDown(sub.close);
      expect((await c.read(discoverHomeProvider.future)).where.city, 'Kochi');
      expect(discover.homes, 1);

      status.reportOffline();
      discover.city = 'Thrissur';
      status.reportOnline();
      await Future<void>.delayed(Duration.zero);
      await c.read(discoverHomeProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(discover.homes, 2);
      expect(c.read(discoverHomeProvider).valueOrNull?.where.city, 'Thrissur');
    });

    test('a paged list (Find events) refreshes its first page', () async {
      final discover = _Discover();
      final c = container(discover);
      final sub = c.listen(eventSearchProvider(EventFilters.none), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      expect(discover.eventPages, 1);

      status.reportOffline();
      status.reportOnline();
      await Future<void>.delayed(Duration.zero);
      expect(discover.eventPages, 2);
    });

    test('nothing is asked while it stays offline', () async {
      final discover = _Discover();
      final c = container(discover);
      final sub = c.listen(discoverHomeProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(discoverHomeProvider.future);

      status.reportOffline();
      status.reportOffline();
      await Future<void>.delayed(Duration.zero);
      expect(discover.homes, 1);
    });
  });

  test('a failure here is a Failure, as the providers throw it', () {
    // Guards the fake: the providers throw the Failure a repository gives.
    expect(const NetworkFailure(message: 'x'), isA<Failure>());
  });
}
