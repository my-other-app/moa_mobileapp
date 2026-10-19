import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/networking_page.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../threads/moderation_fakes.dart';
import 'events_fakes.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<FakeModerationRepository> _pumpNetworking(WidgetTester tester,
    {bool signedIn = true}) async {
  final moderation = FakeModerationRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      moderationRepositoryProvider.overrideWithValue(moderation),
      isAuthenticatedProvider.overrideWithValue(signedIn),
    ],
    child: const MaterialApp(
      home: NetworkingPage(eventId: 7, eventName: 'Hack Night'),
    ),
  ));
  await _settle(tester);
  return moderation;
}

const _people = {
  'event_id': 7,
  'event_name': 'Hack Night',
  'window_closes_at': null,
  'total': 2,
  'attendees': [
    {
      'user_id': 41,
      'name': 'Ravi Kumar',
      'profile_pic_url': null,
      'organization': 'CET',
      'shared_interests': [
        {'id': 1, 'name': 'AI'},
      ],
      'match_count': 1,
    },
    {
      'user_id': 42,
      'name': 'Neha',
      'profile_pic_url': null,
      'organization': null,
      'shared_interests': [],
      'match_count': 0,
    },
  ],
};

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

  group('report and block, on each person', () {
    testWidgets('report a person: the reason, then the thanks',
        (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people);
      final moderation = await _pumpNetworking(tester);

      await tester.tap(find.byKey(const ValueKey('person-menu-41')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('REPORT PERSON'), findsOneWidget);

      await tester.tap(find.text('Spam or scam'));
      await tester.pump();
      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      expect(moderation.calls, ['report']);
      expect(moderation.lastTarget, ReportTarget.user(41));
      expect(moderation.lastReason, ReportReason.spam);
      expect(find.text('Thanks — our team will review this.'), findsOneWidget);
    });

    testWidgets('block a person: asked first, then gone from the list',
        (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people);
      final moderation = await _pumpNetworking(tester);
      expect(find.text('Ravi Kumar'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('person-menu-41')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('BLOCK RAVI KUMAR?'), findsOneWidget);

      await tester.tap(find.text('BLOCK'));
      await tester.pumpAndSettle();

      expect(moderation.calls, ['block:41']);
      expect(find.text('Ravi Kumar'), findsNothing);
      expect(find.text('Neha'), findsOneWidget);
      expect(find.text('Ravi Kumar is blocked.'), findsOneWidget);
    });

    testWidgets('changing their mind blocks no one', (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people);
      final moderation = await _pumpNetworking(tester);

      await tester.tap(find.byKey(const ValueKey('person-menu-42')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(moderation.calls, isEmpty);
      expect(find.text('Neha'), findsOneWidget);
    });
  });
}
