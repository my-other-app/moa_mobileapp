import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/events_routes.dart';
import 'package:finnet/features/events/presentation/pages/competition_page.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/pages/feedback_survey_page.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The app's event routes, as app_router.dart has them once batch D uses
/// the builders: batch B's routes at the top, the event page and its form
/// under the shell's `/events`.
GoRouter _router(String location) => GoRouter(
      initialLocation: location,
      routes: [
        ...eventsRoutes,
        ShellRoute(
          builder: (context, state, child) => child,
          routes: [
            GoRoute(
              path: '/events',
              builder: (_, __) => const Text('my events'),
              routes: [
                GoRoute(
                    path: 'explore', builder: (_, __) => const Text('explore')),
                GoRoute(
                  path: ':eventId',
                  builder: buildEventPage,
                  routes: [
                    GoRoute(path: 'register', builder: buildEventRegisterPage),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

Future<void> _open(WidgetTester tester, String location) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: MaterialApp.router(routerConfig: _router(location)),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('the event page builder', () {
    testWidgets('/events/{slug} opens that event, not event 0', (tester) async {
      await _open(tester, '/events/hack-night');

      final page =
          tester.widget<IndividualEventPage>(find.byType(IndividualEventPage));
      expect(page.ref, 'hack-night');
      expect(page.eventId, isNull);
      expect(api.sent('GET', '/events/info/hack-night'), hasLength(1));
      expect(api.sent('GET', '/events/info/0'), isEmpty);
    });

    testWidgets('/events/{id} opens it by id', (tester) async {
      await _open(tester, '/events/42');

      final page =
          tester.widget<IndividualEventPage>(find.byType(IndividualEventPage));
      expect(page.eventId, 42);
      expect(api.sent('GET', '/events/info/42'), hasLength(1));
    });

    testWidgets('?live opens the live room at once', (tester) async {
      await _open(tester, '/events/hack-night?live=quiz');
      final page =
          tester.widget<IndividualEventPage>(find.byType(IndividualEventPage));
      expect(page.openLiveRoom, isTrue);
    });

    testWidgets('/events/explore is still Explore, not an event',
        (tester) async {
      await _open(tester, '/events/explore');
      expect(find.text('explore'), findsOneWidget);
      expect(find.byType(IndividualEventPage), findsNothing);
    });
  });

  testWidgets('/events/{slug}/register is the form, reading its event by slug',
      (tester) async {
    await _open(tester, '/events/hack-night/register');

    final form = tester.widget<EventFormPage>(find.byType(EventFormPage));
    expect(form.eventRef, 'hack-night');
    expect(form.eventId, isNull);
    expect(form.additionalDetails, isNull);
    // The form reads it, and so does the event page under it (Back from a
    // linked form lands on the event).
    expect(api.sent('GET', '/events/info/hack-night'), isNotEmpty);
    expect(api.sent('GET', '/events/info/0'), isEmpty);
    expect(
        find.byType(IndividualEventPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('/events/{slug}/compete is "Your team"', (tester) async {
    await _open(tester, '/events/hack-night/compete');

    final page = tester.widget<CompetitionPage>(find.byType(CompetitionPage));
    expect(page.eventRef, 'hack-night');
    expect(find.byType(IndividualEventPage), findsNothing);
  });

  testWidgets('/feedback/{event}/{registration}?k= is the survey',
      (tester) async {
    await _open(tester, '/feedback/7/6f1c2d4e?k=abc.def');

    final page =
        tester.widget<FeedbackSurveyPage>(find.byType(FeedbackSurveyPage));
    expect(page.eventId, 7);
    expect(page.registrationId, '6f1c2d4e');
    expect(page.surveyKey, 'abc.def');
  });

  group("in the app's router", () {
    GoRouter appRouter() {
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(
            const AuthState(accessToken: 'token', isInitialized: true))),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      return container.read(routerProvider);
    }

    String? nameAt(GoRouter router, String location) =>
        router.configuration.findMatch(Uri.parse(location)).last.route.name;

    test('the new routes are reachable, and the old ones unchanged', () {
      final router = appRouter();
      expect(nameAt(router, '/events/hack-night/compete'),
          EventRouteNames.competition);
      expect(nameAt(router, '/events/42/compete'), EventRouteNames.competition);
      expect(nameAt(router, '/feedback/7/abc'), EventRouteNames.feedback);
      expect(nameAt(router, '/events/hack-night'), 'eventDetail');
      expect(nameAt(router, '/events/hack-night/register'), 'eventRegister');
      expect(nameAt(router, '/events/explore'), 'exploreEvents');
    });
  });
}
