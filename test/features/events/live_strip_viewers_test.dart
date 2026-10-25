import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

/// The live strip for each kind of viewer. (The strip's stream, its clocks
/// and the background are in individual_event_page_test.dart, with a
/// registered viewer.)
Map<String, dynamic> _info({required bool registered, bool attended = false}) =>
    {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': false,
      'reg_fee': 0,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': <dynamic>[],
      'is_registered': registered,
      'is_attended': attended,
      'ticket_url': registered ? 'https://myotherapp.in/tickets/T-1' : null,
      if (registered) 'is_paid': true,
    };

const _room = {
  'event': {'id': 7, 'name': 'Hack Night', 'status': 'live'},
  'banner': {'kind': 'room', 'text': 'Demos move to Lab 3B'},
  'poll': null,
  'questions': <dynamic>[],
  'quiz': {'live': false, 'title': null},
};

Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
    ],
    child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('a checked-in ticket holder sees the strip', (tester) async {
    useFakeApi()
      ..on('GET', '/events/info/7', _info(registered: true, attended: true))
      ..on('GET', '/events/7/live', _room);
    await _pump(tester);

    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Demos move to Lab 3B'), findsOneWidget);
  });

  testWidgets('someone without a ticket sees the strip too', (tester) async {
    final api = useFakeApi()
      ..on('GET', '/events/info/7', _info(registered: false))
      ..on('GET', '/events/7/live', _room);
    await _pump(tester);

    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Demos move to Lab 3B'), findsOneWidget);
    expect(api.sent('GET', '/events/7/live'), hasLength(1));
  });
}
