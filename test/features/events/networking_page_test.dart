import 'package:finnet/features/events/presentation/pages/networking_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

Future<void> _pumpNetworking(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: NetworkingPage(eventId: 7, eventName: 'Hack Night'),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('a plan without networking says so, with nothing to retry',
      (tester) async {
    // What the audit saw: "ApiException: You do not have permission…
    // (forbidden, code: 403)".
    useFakeApi().on(
        'GET',
        '/events/7/networking',
        {
          'message': 'You do not have permission to access this resource.',
          'error_code': 'NETWORKING_UNAVAILABLE',
        },
        status: 403);
    await _pumpNetworking(tester);

    expect(find.text("Networking isn't available for this event."),
        findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.textContaining('permission'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('anything else can be retried', (tester) async {
    useFakeApi()
        .on('GET', '/events/7/networking', {'message': 'Oops'}, status: 503);
    await _pumpNetworking(tester);

    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });
}
