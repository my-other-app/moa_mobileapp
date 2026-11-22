import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:finnet/core/network/interceptors/logging_interceptor.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/services/crash_reporting.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/games/domain/games.dart';
import 'package:finnet/features/games/presentation/game_play_buttons.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';

const _secret = 'gs.SECRET-session-token-9f3a';

Map<String, dynamic> _public({Object? cards, Object? hunt}) => {
      'event': {'id': 7, 'name': 'Hack Night', 'slug': 'hack-night'},
      'cards': cards,
      'hunt': hunt,
      'theme': 'neon_arcade',
      'logo_url': null,
    };

Map<String, dynamic> _info() => {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': false,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': null,
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': const [],
      'rating': 0,
      'total_rating': 0,
      'is_registered': true,
      'ticket_url': 'https://myotherapp.in/tickets/T-1',
    };

late RouteAdapter api;
late List<Uri> opened;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpButtons(
  WidgetTester tester, {
  String? ref = 'hack-night',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        linkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(body: GamePlayButtons(eventId: 7, eventRef: ref)),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, GameKind kind) async {
  await tester.tap(find.byKey(GamePlayButtons.buttonKey(kind)));
  await _settle(tester);
}

void main() {
  setUp(() {
    api = useFakeApi();
    opened = [];
  });

  group('the public card', () {
    test('reads the games that are on, with their names', () {
      final games = EventGames.fromJson(
        _public(
          cards: {'on': true, 'name': 'Hero Cards'},
          hunt: {'on': true, 'name': 'Treasure Trail'},
        ),
      );
      expect(games.offers.map((o) => o.label), [
        'Play Hero Cards',
        'Play Treasure Trail',
      ]);
    });

    test('an unnamed game takes its default name', () {
      final games = EventGames.fromJson(
        _public(cards: {'on': true}, hunt: {'on': true, 'name': '  '}),
      );
      expect(games.offers.map((o) => o.name), ['Hero Cards', 'Scavenger Hunt']);
    });

    test('odd shapes are no games', () {
      for (final odd in <Object?>[
        null,
        'x',
        42,
        const [],
        {'cards': 'yes', 'hunt': 3},
        {
          'cards': {'on': 'true'},
          'hunt': {'on': false},
        },
        {
          'cards': {'name': 'Hero Cards'},
        },
      ]) {
        expect(EventGames.fromJson(odd).isEmpty, isTrue, reason: '$odd');
      }
    });

    test('the link carries the session in the fragment', () {
      expect(
        gameLinkFor('hack-night', 'a b').toString(),
        'https://myotherapp.in/play/hack-night#gs=a%20b',
      );
    });
  });

  group('the buttons', () {
    testWidgets('one for each game that is on, by its name', (tester) async {
      api.on(
        'GET',
        '/games/7/public',
        _public(
          cards: {'on': true, 'name': 'Hero Cards'},
          hunt: {'on': true, 'name': 'Treasure Trail'},
        ),
      );
      await _pumpButtons(tester);

      expect(find.text('Play Hero Cards'), findsOneWidget);
      expect(find.text('Play Treasure Trail'), findsOneWidget);
    });

    testWidgets('only the game that is on', (tester) async {
      api.on(
        'GET',
        '/games/7/public',
        _public(
          cards: {'on': false, 'name': 'Hero Cards'},
          hunt: {'on': true, 'name': 'Scavenger Hunt'},
        ),
      );
      await _pumpButtons(tester);

      expect(find.text('Play Hero Cards'), findsNothing);
      expect(find.text('Play Scavenger Hunt'), findsOneWidget);
    });

    testWidgets('none when both are null, off, absent, odd, or a 404', (
      tester,
    ) async {
      for (final body in <Object?>[
        _public(),
        _public(cards: {'on': false}, hunt: {'on': false}),
        <String, dynamic>{},
        ['unexpected'],
        'text',
      ]) {
        await tester.pumpWidget(const SizedBox());
        final fresh = useFakeApi()..on('GET', '/games/7/public', body);
        await _pumpButtons(tester);
        expect(find.byType(OutlinedButton), findsNothing, reason: '$body');
        expect(fresh.sent('POST', '/games/7/session'), isEmpty);
      }
      useFakeApi().on(
          'GET',
          '/games/7/public',
          {
            'message': 'Not found',
          },
          status: 404);
      await _pumpButtons(tester);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('a tap', () {
    testWidgets('makes a session and opens the game, signed in', (
      tester,
    ) async {
      api
        ..on(
          'GET',
          '/games/7/public',
          _public(cards: {'on': true, 'name': 'Hero Cards'}),
        )
        ..on('POST', '/games/7/session', {
          'token': _secret,
          'expires_at': '2030-12-02T00:00:00Z',
        });
      await _pumpButtons(tester);
      await _tap(tester, GameKind.cards);

      expect(api.sent('POST', '/games/7/session'), hasLength(1));
      expect(opened, hasLength(1));
      expect(
        opened.single.toString(),
        'https://myotherapp.in/play/hack-night#gs=${Uri.encodeComponent(_secret)}',
      );
      expect(opened.single.fragment, 'gs=${Uri.encodeComponent(_secret)}');
      expect(opened.single.query, isEmpty);
    });

    testWidgets('uses the server\'s slug when the screen has none',
        (tester) async {
      api
        ..on('GET', '/games/7/public', _public(hunt: {'on': true}))
        ..on('POST', '/games/7/session', {'token': 't1', 'expires_at': 'x'});
      await _pumpButtons(tester, ref: null);
      await _tap(tester, GameKind.hunt);

      expect(opened.single.toString(),
          'https://myotherapp.in/play/hack-night#gs=t1');
    });

    testWidgets('never the id: no slug anywhere hides the buttons',
        (tester) async {
      api.on('GET', '/games/7/public', {
        'event': {'id': 7, 'name': 'Hack Night', 'slug': ''},
        'cards': {'on': true},
        'hunt': {'on': true},
      });
      await _pumpButtons(tester, ref: '7');

      expect(find.byType(OutlinedButton), findsNothing);
      expect(api.sent('POST', '/games/7/session'), isEmpty);
    });

    testWidgets('me.can_play false hides them; true or absent shows them',
        (tester) async {
      Map<String, dynamic> withMe(Object? me) => {
            ..._public(cards: {'on': true}),
            if (me != null) 'me': me
          };
      for (final (me, shown) in <(Object?, bool)>[
        ({'can_play': false, 'reason': 'NOT_CHECKED_IN'}, false),
        ({'can_play': true, 'reason': null}, true),
        (null, true),
        ({'reason': 'x'}, true),
      ]) {
        await tester.pumpWidget(const SizedBox());
        useFakeApi().on('GET', '/games/7/public', withMe(me));
        await _pumpButtons(tester);
        expect(
            find.text('Play Hero Cards'), shown ? findsOneWidget : findsNothing,
            reason: '$me');
      }
    });

    for (final refusal in [
      ('NOT_CHECKED_IN', 403, 'Check in at the desk first'),
      (
        'PLAN_FEATURE_REQUIRED',
        402,
        'Games are not part of this club\'s plan.',
      ),
      ('SOMETHING_ELSE', 400, 'The games are closed for now.'),
    ]) {
      testWidgets('${refusal.$1} shows the server\'s words', (tester) async {
        api
          ..on('GET', '/games/7/public', _public(cards: {'on': true}))
          ..on(
              'POST',
              '/games/7/session',
              {
                'message': refusal.$3,
                'error_code': refusal.$1,
              },
              status: refusal.$2);
        await _pumpButtons(tester);
        await _tap(tester, GameKind.cards);

        expect(find.text(refusal.$3), findsOneWidget);
        expect(opened, isEmpty);
      });
    }

    testWidgets('a server fault says so in plain words', (tester) async {
      api
        ..on('GET', '/games/7/public', _public(cards: {'on': true}))
        ..on('POST', '/games/7/session', {'detail': 'boom'}, status: 500);
      await _pumpButtons(tester);
      await _tap(tester, GameKind.cards);

      expect(find.textContaining('went wrong'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('an answer without a token opens nothing', (tester) async {
      api
        ..on('GET', '/games/7/public', _public(cards: {'on': true}))
        ..on('POST', '/games/7/session', {'expires_at': 'x'});
      await _pumpButtons(tester);
      await _tap(tester, GameKind.cards);

      expect(opened, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('offline shows the usual offline words', (tester) async {
      api.on('GET', '/games/7/public', _public(cards: {'on': true}));
      await _pumpButtons(tester);
      APIService.instance.dio.httpClientAdapter = _OfflineAdapter(
        APIService.instance.dio.httpClientAdapter,
      );
      await _tap(tester, GameKind.cards);

      expect(find.text(ApiException.networkMessage), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('a browser that will not open says so', (tester) async {
      api
        ..on('GET', '/games/7/public', _public(cards: {'on': true}))
        ..on('POST', '/games/7/session', {'token': 't1', 'expires_at': 'x'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkLauncherProvider.overrideWithValue((_) async => false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: GamePlayButtons(eventId: 7)),
          ),
        ),
      );
      await _settle(tester);
      await _tap(tester, GameKind.cards);

      expect(
        find.text("Couldn't open the game. Please try again."),
        findsOneWidget,
      );
    });
  });

  group('where the buttons are', () {
    testWidgets('on the ticket, in its own style', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      api
        ..on(
          'GET',
          '/games/7/public',
          _public(
            cards: {'on': true, 'name': 'Hero Cards'},
            hunt: {'on': true, 'name': 'Scavenger Hunt'},
          ),
        )
        ..on('POST', '/games/7/session', {'token': 't9', 'expires_at': 'x'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkLauncherProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
          ],
          child: const MaterialApp(
            home: TicketViewPage(
              ticketId: 'T-1',
              eventName: 'Hack Night',
              eventId: 7,
            ),
          ),
        ),
      );
      await _settle(tester);

      final cards = find.byKey(GamePlayButtons.buttonKey(GameKind.cards));
      expect(cards, findsOneWidget);
      expect(find.text('Play Scavenger Hunt'), findsOneWidget);
      await tester.ensureVisible(cards);
      await tester.pump();
      await tester.tap(cards);
      await _settle(tester);

      // The ticket knows only the id; the server's card gives the slug.
      expect(opened.single.toString(),
          'https://myotherapp.in/play/hack-night#gs=t9');
    });

    testWidgets('not on a revoked ticket', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      api.on('GET', '/games/7/public', _public(cards: {'on': true}));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TicketViewPage(
              ticketId: 'T-1',
              eventName: 'Hack Night',
              eventId: 7,
              revoked: true,
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Play Hero Cards'), findsNothing);
    });

    testWidgets('on the event page for someone registered', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      api
        ..on('GET', '/events/info/7', _info())
        ..on(
          'GET',
          '/games/7/public',
          _public(hunt: {'on': true, 'name': 'Scavenger Hunt'}),
        )
        ..on('POST', '/games/7/session', {'token': 't5', 'expires_at': 'x'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(),
            ),
            paymentRepositoryProvider.overrideWithValue(
              FakePaymentRepository(),
            ),
            isAuthenticatedProvider.overrideWithValue(true),
            linkLauncherProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
          ],
          child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
        ),
      );
      await _settle(tester);

      expect(find.text('VIEW TICKET'), findsOneWidget);
      expect(find.text('Play Scavenger Hunt'), findsOneWidget);
      await tester.tap(find.text('Play Scavenger Hunt'));
      await _settle(tester);
      expect(
        opened.single.toString(),
        'https://myotherapp.in/play/hack-night#gs=t5',
      );
    });

    testWidgets('not for someone who has not registered', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      api
        ..on('GET', '/events/info/7', {
          ..._info(),
          'is_registered': false,
          'ticket_url': null,
        })
        ..on('GET', '/games/7/public', _public(cards: {'on': true}));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(),
            ),
            paymentRepositoryProvider.overrideWithValue(
              FakePaymentRepository(),
            ),
            isAuthenticatedProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
        ),
      );
      await _settle(tester);

      expect(find.text('Play Hero Cards'), findsNothing);
    });
  });

  group('the token stays out of logs', () {
    test('a report loses it from the address', () {
      final url = gameLinkFor('hack-night', _secret).toString();
      final redacted = redactForCrashReport('opening $url failed');
      expect(redacted, isNot(contains(_secret)));
      expect(redacted, contains('#gs=<token>'));
    });

    testWidgets('nothing printed, logged or reported carries it', (
      tester,
    ) async {
      final lines = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      APIService.instance.dio.interceptors.add(LoggingInterceptor());

      final reports = <String>[];
      final reporter = CrashReporter(
        sink: _RecordingSink(reports),
        enabled: () => true,
      );

      await runZoned(
        () async {
          api
            ..on('GET', '/games/7/public', _public(cards: {'on': true}))
            ..on('POST', '/games/7/session', {
              'token': _secret,
              'expires_at': '2030-12-02T00:00:00Z',
            });
          await _pumpButtons(tester);
          await _tap(tester, GameKind.cards);
          // And a failure reported on the way out, as the app does.
          reporter.recordNonFatal(
            'could not open ${opened.single}',
            StackTrace.current,
          );
          await tester.pump();
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => lines.add(line),
        ),
      );

      debugPrint = oldDebugPrint;

      expect(opened, hasLength(1));
      expect(lines, isNotEmpty);
      expect(lines.where((l) => l.contains(_secret)), isEmpty);
      expect(reports, isNotEmpty);
      expect(reports.where((r) => r.contains(_secret)), isEmpty);
    });
  });
}

class _RecordingSink implements CrashSink {
  _RecordingSink(this.out);
  final List<String> out;

  @override
  Future<void> recordError(
    String exception,
    StackTrace? stack, {
    String? reason,
    List<String> information = const [],
    required bool fatal,
  }) async {
    out.add('$exception ${reason ?? ''} ${information.join(' ')}');
  }

  @override
  Future<void> log(String message) async => out.add(message);
}

/// Every request fails as if the phone had no network.
class _OfflineAdapter implements HttpClientAdapter {
  _OfflineAdapter(this._inner);
  final HttpClientAdapter _inner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('offline'),
      );
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
