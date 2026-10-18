import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/clubs/presentation/pages/club_events_page.dart';
import 'package:finnet/shared/utils/share_links.dart';
import 'package:finnet/shared/widgets/custom_search_delegate.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// An EventCard inside a router, recording where it navigates.
Future<List<(String, Object?)>> _pumpCard(
  WidgetTester tester, {
  EventCardStatus status = EventCardStatus.none,
  String eventSlug = 'build-a-robot',
}) async {
  final pushed = <(String, Object?)>[];
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: SingleChildScrollView(
          child: EventCard(
            title: 'Build a robot',
            organizer: 'Tinkerhub CET',
            categoryId: 2,
            categoryName: 'Workshop',
            startsAt: DateTime.utc(2026, 10, 16, 20),
            tags: const ['Workshop', 'Offline', 'Paid'],
            onTap: () {},
            orgImage: '',
            eventId: 7,
            clubId: 1,
            clubSlug: 'tinkerhub-cet',
            eventSlug: eventSlug,
            status: status,
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (_, state) {
        pushed.add((state.uri.toString(), state.extra));
        return const Scaffold(body: Text('event page'));
      },
    ),
  ]);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  return pushed;
}

void main() {
  group('ErrorView', () {
    testWidgets("shows the caller's message, not generic copy",
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ErrorView(message: "Couldn't load your blocked list."),
      ));
      expect(find.text("Couldn't load your blocked list."), findsOneWidget);
    });

    test('raw exception strings give way to friendly copy', () {
      expect(readableErrorMessage(null), isNull);
      expect(readableErrorMessage('   '), isNull);
      expect(
        readableErrorMessage('DioException [connection error]: nope'),
        isNull,
      );
      expect(readableErrorMessage("Instance of 'TypeError'"), isNull);
      expect(
        readableErrorMessage("type 'Null' is not a subtype of type 'int'"),
        isNull,
      );
      expect(readableErrorMessage('Club not found'), 'Club not found');
    });

    testWidgets('an exception still speaks for itself', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ErrorView(
          message: 'ignored',
          exception: ApiException(
            message: 'x',
            type: ApiExceptionType.network,
          ),
        ),
      ));
      expect(find.text('Please check your internet connection and try again.'),
          findsOneWidget);
      expect(find.text('ignored'), findsNothing);
    });
  });

  group('EventCard awaiting payment', () {
    test('only a registration with a fee and is_paid false owes it', () {
      expect(
        registeredCardStatus({'has_fee': true, 'is_paid': false}),
        EventCardStatus.awaitingPayment,
      );
      expect(
        registeredCardStatus({'has_fee': true, 'is_paid': true}),
        EventCardStatus.registered,
      );
      // No is_paid at all is not read as unpaid.
      expect(registeredCardStatus({'has_fee': true}), EventCardStatus.registered);
      expect(
        registeredCardStatus({'has_fee': false, 'is_paid': false}),
        EventCardStatus.registered,
      );
    });

    testWidgets('shows Payment due and FINISH PAYMENT, which starts payment',
        (tester) async {
      final pushed =
          await _pumpCard(tester, status: EventCardStatus.awaitingPayment);

      expect(find.byKey(const ValueKey('payment-due-badge')), findsOneWidget);
      expect(find.text('Payment due'), findsOneWidget);
      final button = find.byKey(const ValueKey('event-finish-payment'));
      expect(find.text('FINISH PAYMENT'), findsOneWidget);

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(pushed.single.$1, '/events/7');
      expect(pushed.single.$2, {'status': 'finishPayment'});
    });

    testWidgets('a paid registration keeps VIEW TICKET', (tester) async {
      await _pumpCard(tester, status: EventCardStatus.registered);

      expect(find.text('VIEW TICKET'), findsOneWidget);
      expect(find.text('FINISH PAYMENT'), findsNothing);
      expect(find.text('Payment due'), findsNothing);
    });
  });

  group('EventCard share', () {
    late List<MethodCall> calls;

    setUp(() => calls = []);

    Future<void> mockShare(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _shareChannel,
        (call) async {
          calls.add(call);
          return 'dev.fluttercommunity.plus/share/unavailable';
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, null));
    }

    testWidgets("shares the event's public page instead of opening it",
        (tester) async {
      await mockShare(tester);
      await _pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('event-share')));
      await tester.pump();

      final text = (calls.single.arguments as Map)['text'] as String;
      expect(text, contains('https://myotherapp.in/events/build-a-robot'));
      expect(text, contains('Build a robot'));
    });

    testWidgets('an event without a slug shares its id link', (tester) async {
      await mockShare(tester);
      await _pumpCard(tester, eventSlug: '');

      await tester.tap(find.byKey(const ValueKey('event-share')));
      await tester.pump();

      expect((calls.single.arguments as Map)['text'],
          contains('https://myotherapp.in/events/7'));
    });

    test('the event link helper', () {
      expect(eventPageUrl(slug: 'a b', id: 7),
          'https://myotherapp.in/events/a%20b');
      expect(eventPageUrl(slug: null, id: 7), 'https://myotherapp.in/events/7');
      expect(eventPageUrl(slug: '', id: 0), isNull);
    });
  });

  group('search endpoints encode the query', () {
    test('events', () {
      expect(
        eventSearchEndpoint('C++ & AI #1'),
        '/events/list?search=C%2B%2B+%26+AI+%231&offset=0&limit=20',
      );
      expect(
        eventSearchEndpoint('robot', filterType: 'registered'),
        '/events/list?search=robot&offset=0&limit=20'
        '&is_registered=true&is_ended=false',
      );
      expect(
        eventSearchEndpoint('robot', filterType: 'following'),
        endsWith('&is_following=true'),
      );
      expect(
        eventSearchEndpoint('robot', filterType: 'past'),
        endsWith('&is_registered=true&is_ended=true'),
      );
    });

    test('clubs', () {
      expect(
        clubSearchEndpoint('IEDC & IEEE'),
        '/clubs/list?search=IEDC+%26+IEEE&offset=0&limit=20',
      );
    });
  });

  group("a club's event length tag", () {
    test('is left out rather than "null Hours"', () {
      expect(clubEventLengthLabel(null), isNull);
      expect(clubEventLengthLabel('soon'), isNull);
      expect(clubEventLengthLabel(0), isNull);
      expect(clubEventLengthLabel(2), '2 Hours');
      expect(clubEventLengthLabel(2.5), '2.5 Hours');
      expect(clubEventLengthLabel('1'), '1 Hour');
    });
  });
}
