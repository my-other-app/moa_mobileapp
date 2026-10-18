import 'dart:convert';

import 'package:finnet/features/auth/presentation/pages/interests_selection_page.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import 'topic_fixtures.dart';

Finder _chip(int id) => find.byKey(ValueKey('interest-chip-$id'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required bool onboarding,
  List<Interest> chosen = const [],
}) async {
  final profiles = FakeProfileRepository()
    ..profile = UserProfile(
      id: 'u-1',
      fullName: 'Asha Menon',
      email: 'asha@example.com',
      interests: chosen,
    );
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('edit profile')),
      ),
      GoRoute(
        path: '/interests',
        builder: (_, __) => InterestsSelectionPage(isOnboarding: onboarding),
      ),
      GoRoute(
        path: '/onboarding/avatar',
        builder: (_, __) => const Scaffold(body: Text('avatar step')),
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
    child: MaterialApp.router(routerConfig: router),
  ));
  router.push('/interests');
  await _settle(tester);
  return router;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('interests come from /interests/list, grouped by topic',
      (tester) async {
    api.on('GET', '/interests/list', contractListBody);
    await _pump(tester, onboarding: true);

    expect(api.sent('GET', '/interests/list'), hasLength(1));
    expect(find.byKey(const ValueKey('topic-header-development')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('topic-header-arts')), findsOneWidget);
    expect(_chip(3), findsOneWidget);
    expect(_chip(15), findsOneWidget);
  });

  testWidgets(
      'what the person already has is chosen; saving sends the same call',
      (tester) async {
    api
      ..on('GET', '/interests/list', contractListBody)
      ..on('POST', '/user/interests/select', {'id': 1});
    await _pump(tester,
        onboarding: false,
        chosen: const [Interest(id: 6, name: 'Coding')]);

    expect(find.text('1 of 5 selected'), findsOneWidget);

    await tester.tap(_chip(15));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('interests-continue')));
    await _settle(tester);

    final sent = api.sent('POST', '/user/interests/select').single;
    final body = sent.data is String
        ? jsonDecode(sent.data as String)
        : sent.data as Map<String, dynamic>;
    expect(body['interest_ids'], [6, 15]);
    // From Edit Profile it goes back.
    expect(find.text('edit profile'), findsOneWidget);
  });

  testWidgets('in onboarding, saving moves on to the avatar step',
      (tester) async {
    api
      ..on('GET', '/interests/list', productionListBody)
      ..on('POST', '/user/interests/select', {'id': 1});
    await _pump(tester, onboarding: true);

    await tester.tap(_chip(7));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('interests-continue')));
    await _settle(tester);

    expect(find.text('avatar step'), findsOneWidget);
  });

  testWidgets('nothing chosen, nothing to continue with', (tester) async {
    api.on('GET', '/interests/list', productionListBody);
    await _pump(tester, onboarding: true);

    final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('interests-continue')));
    expect(button.onPressed, isNull);

    await tester.tap(_chip(6));
    await _settle(tester);
    expect(
      tester
          .widget<ElevatedButton>(
              find.byKey(const ValueKey('interests-continue')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a sixth is refused with a word of explanation',
      (tester) async {
    api.on('GET', '/interests/list', productionListBody);
    await _pump(tester,
        onboarding: true,
        chosen: const [
          Interest(id: 6, name: 'Coding'),
          Interest(id: 7, name: 'UI/UX'),
          Interest(id: 15, name: 'Photography'),
          Interest(id: 100, name: 'Retired one'),
          Interest(id: 101, name: 'Another'),
        ]);
    expect(find.text('5 of 5 selected'), findsOneWidget);

    await tester.tap(_chip(16));
    await _settle(tester);

    expect(find.text('5 of 5 selected'), findsOneWidget);
    expect(find.textContaining('up to 5 interests'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that loads again',
      (tester) async {
    api
      ..on('GET', '/interests/list', {'message': 'down'}, status: 503)
      ..on('GET', '/interests/list', productionListBody);
    await _pump(tester, onboarding: true);

    expect(find.text('Could not load interests.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await _settle(tester);

    expect(_chip(6), findsOneWidget);
  });
}
