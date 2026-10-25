import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

/// `/events/info/7` for someone who attended Hack Night, which [raters]
/// participants have rated [rating] on average.
Map<String, dynamic> _attended({
  double rating = 4.5,
  int raters = 4,
  double? userRating,
}) =>
    {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'poster': null,
      'event_datetime': '2020-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': false,
      'reg_fee': 0,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': '2020-11-30T00:00:00Z',
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub', 'logo': {}},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': <dynamic>[],
      'rating': rating,
      'total_rating': raters,
      'is_registered': true,
      'is_attended': true,
      'is_paid': true,
      'ticket_url': 'https://myotherapp.in/tickets/T-1',
      'certificate_url': 'https://myotherapp.in/certificates/T-1',
      if (userRating != null) 'user_rating': userRating,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(WidgetTester tester, {bool signedIn = true}) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(signedIn),
    ],
    child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
  ));
  await _settle(tester);
}

/// Opens the sheet from "Rate the Event".
Future<void> _openSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Rate the Event'));
  await tester.tap(find.text('Rate the Event'));
  await _settle(tester);
}

FilledButton _submit(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'SUBMIT'));

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets(
      'someone who attended sees the average and how many rated, and is '
      'asked to rate', (tester) async {
    api.on('GET', '/events/info/7', _attended());
    await _pump(tester);

    expect(find.text('4.5 RATED'), findsOneWidget);
    expect(find.text('Rated by 4 Participants'), findsOneWidget);
    expect(find.text('Rate the Event'), findsOneWidget);
  });

  testWidgets('the sheet names the club; SUBMIT waits for a rating',
      (tester) async {
    api.on('GET', '/events/info/7', _attended());
    await _pump(tester);
    await _openSheet(tester);

    expect(find.text('RATE YOUR EXPERIENCE'), findsOneWidget);
    expect(find.textContaining('How Tinkerhub do?', findRichText: true),
        findsOneWidget);
    expect(_submit(tester).onPressed, isNull);

    await tester.tap(find.text('😸'));
    await tester.pump();
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets(
      'four stars and a review are sent to /events/rate/7; the thanks shows '
      'and the button goes', (tester) async {
    api
      ..on('GET', '/events/info/7', _attended())
      ..on('POST', '/events/rate/7', {'message': 'Rated'});
    await _pump(tester);
    await _openSheet(tester);

    await tester.tap(find.text('😸'));
    await tester.enterText(find.byType(TextField), 'Great mentors');
    await tester.pump();
    await tester.tap(find.text('SUBMIT'));
    await _settle(tester);

    final sent = api.sent('POST', '/events/rate/7');
    expect(sent, hasLength(1));
    expect(sent.single.data, {'rating': 4, 'review': 'Great mentors'});
    expect(find.text('RATE YOUR EXPERIENCE'), findsNothing);
    expect(find.text('Thanks for your rating!'), findsOneWidget);
    expect(find.text('Rate the Event'), findsNothing);
    // The average shown is still the event's.
    expect(find.text('4.5 RATED'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a rating without a review sends no review', (tester) async {
    api
      ..on('GET', '/events/info/7', _attended())
      ..on('POST', '/events/rate/7', {'message': 'Rated'});
    await _pump(tester);
    await _openSheet(tester);

    await tester.tap(find.text('😻'));
    await tester.pump();
    await tester.tap(find.text('SUBMIT'));
    await _settle(tester);

    expect(api.sent('POST', '/events/rate/7').single.data, {'rating': 5});
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a refused rating says why, and the button stays to try again',
      (tester) async {
    api
      ..on('GET', '/events/info/7', _attended())
      ..on('POST', '/events/rate/7',
          {'message': 'You have already rated this event'},
          status: 400);
    await _pump(tester);
    await _openSheet(tester);

    await tester.tap(find.text('😾'));
    await tester.pump();
    await tester.tap(find.text('SUBMIT'));
    await _settle(tester);

    expect(api.sent('POST', '/events/rate/7').single.data, {'rating': 1});
    expect(find.text('You have already rated this event'), findsOneWidget);
    expect(find.text('Rate the Event'), findsOneWidget);
  });

  testWidgets('someone who has rated is not asked again', (tester) async {
    api.on('GET', '/events/info/7', _attended(userRating: 4));
    await _pump(tester);

    expect(find.text('Rate the Event'), findsNothing);
    expect(find.text('4.5 RATED'), findsOneWidget);
  });

  testWidgets('an event nobody has rated yet shows no average',
      (tester) async {
    api.on('GET', '/events/info/7', _attended(rating: 0, raters: 0));
    await _pump(tester);

    expect(find.textContaining(' RATED'), findsNothing);
    expect(find.text('Rate the Event'), findsOneWidget);
  });

  testWidgets('signed out, rating asks for an account first and sends nothing',
      (tester) async {
    api.on('GET', '/events/info/7', _attended());
    await _pump(tester, signedIn: false);
    await _openSheet(tester);

    expect(find.text('Sign in to rate this event.'), findsOneWidget);
    expect(find.text('RATE YOUR EXPERIENCE'), findsNothing);
    expect(api.sent('POST', '/events/rate/7'), isEmpty);
  });
}
