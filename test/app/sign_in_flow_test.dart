import 'package:finnet/app/router/link_pages.dart';
import 'package:finnet/app/router/link_targets.dart';
import 'package:finnet/app/router/pending_location.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/sign_in_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  void set(AuthState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _FakeTargets implements LinkTargets {
  _FakeTargets({this.events = const {}, this.clubs = const {}, this.error});

  final Map<String, int> events;
  final Map<String, LinkedClub> clubs;
  Object? error;
  int asked = 0;

  @override
  Future<int?> eventId(String slug) async {
    asked++;
    if (error != null) throw error!;
    return events[slug];
  }

  @override
  Future<LinkedClub?> club(String slug) async {
    asked++;
    if (error != null) throw error!;
    return clubs[slug];
  }
}

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

/// A small app: home, an event, the profile tab and sign-in, with the
/// pieces under test wired in as the real router wires them.
class _App {
  _App(AuthState start, {LinkTargets? targets}) {
    auth = _FakeAuth(start);
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => auth),
      linkLauncherProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
      if (targets != null) linkTargetsProvider.overrideWithValue(targets),
    ]);
    authValue = ValueNotifier(start);
    container.listen<AuthState>(
        authStateProvider, (_, next) => authValue.value = next);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const _Page('home'),
            routes: [
              GoRoute(
                  path: 'events/:ref',
                  builder: (context, s) => Consumer(
                        builder: (context, ref, _) => Scaffold(
                          appBar: AppBar(),
                          body: Column(children: [
                            Text('event ${s.pathParameters['ref']}'),
                            TextButton(
                              onPressed: () async {
                                if (await requireSignIn(context, ref,
                                    reason: 'Sign in to follow clubs.')) {
                                  followed++;
                                }
                              },
                              child: const Text('Follow'),
                            ),
                          ]),
                        ),
                      )),
            ]),
        GoRoute(path: '/profile', builder: (_, __) => const _Page('profile')),
        GoRoute(
            path: signInPath,
            builder: (_, s) => SignInGate(
                  location: s.uri,
                  child: const _Page('sign in'),
                )),
      ],
    );
    listener = openPendingOnHome(
        router, authValue, container.read(pendingLocationProvider));
  }

  late final _FakeAuth auth;
  late final ValueNotifier<AuthState> authValue;
  late final ProviderContainer container;
  late final GoRouter router;
  late final VoidCallback listener;
  final opened = <Uri>[];
  int followed = 0;

  PendingLocation get pending => container.read(pendingLocationProvider);

  /// On the sign-in screen, as the sign-in flow is before it ends at Home.
  Future<void> signIn(WidgetTester tester) async {
    router.go(signInPath);
    await tester.pumpAndSettle();
  }
  String get location => router.state.uri.toString();

  Future<void> pump(WidgetTester tester) async {
    addTearDown(() {
      router.routerDelegate.removeListener(listener);
      router.dispose();
      container.dispose();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }
}

class _Page extends StatelessWidget {
  const _Page(this.name);

  final String name;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(), body: Text(name));
}

void main() {
  group('a sign-in comes back to where it started', () {
    testWidgets('once signed in, the router landing on Home opens the page',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      await app.signIn(tester);
      app.pending.holdReturn('/events/12');

      // The sign-in flow ends with go('/'), signed in.
      app.auth.set(_signedIn);
      app.router.go('/');
      await tester.pumpAndSettle();

      expect(find.text('event 12'), findsOneWidget);
      expect(app.pending.location, isNull);
      // Over Home: Back returns there.
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a tab comes back as the tab, not above Home', (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      await app.signIn(tester);
      app.pending.holdReturn('/profile');
      app.auth.set(_signedIn);
      app.router.go('/');
      await tester.pumpAndSettle();

      expect(app.location, '/profile');
      expect(app.router.canPop(), isFalse);
    });

    testWidgets('signed out, a sign-in\'s return waits', (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      await app.signIn(tester);
      app.pending.holdReturn('/events/12');
      app.router.go('/');
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(app.pending.location, '/events/12');
    });

    testWidgets('a public link that opened the app opens signed out',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      // As the splash screen hands over.
      await app.signIn(tester);
      app.pending.holdLaunch('/events/hack-night-04');
      app.router.go('/');
      await tester.pumpAndSettle();

      expect(find.text('event hack-night-04'), findsOneWidget);
    });

    testWidgets('a private link that opened the app waits for sign-in',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      await app.signIn(tester);
      app.pending.holdLaunch('/profile');
      app.router.go('/');
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(app.pending.location, '/profile');
    });
  });

  group('the sign-in screen', () {
    testWidgets('holds its "from", and "Not now" forgets it and goes home',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      app.router.go(signInLocation('/profile'));
      await tester.pumpAndSettle();
      expect(app.pending.location, '/profile');

      await tester.tap(find.byKey(const ValueKey('sign-in-not-now')));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(app.pending.location, isNull);
    });

    testWidgets('opened over a page, "Not now" returns to it', (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      app.router.push('/events/12');
      await tester.pumpAndSettle();
      app.router.push(signInLocation('/events/12'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('event 12'), findsOneWidget);
      expect(app.pending.location, isNull);
    });

    testWidgets('Back forgets the return too', (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      app.router.push(signInLocation('/events/12'));
      await tester.pumpAndSettle();
      expect(app.pending.location, '/events/12');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(app.pending.location, isNull);
    });

    testWidgets('ignores a "from" that leaves the app', (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      app.router.go('$signInPath?from=https%3A%2F%2Fevil.example');
      await tester.pumpAndSettle();
      expect(app.pending.location, isNull);
      expect(returnTarget(Uri.parse('$signInPath?from=//evil.example')),
          isNull);
      expect(returnTarget(Uri.parse(signInLocation('/auth/onboarding'))),
          isNull);
    });
  });

  group('requireSignIn', () {
    testWidgets('signed in, it says yes and asks nothing', (tester) async {
      final app = _App(_signedIn);
      await app.pump(tester);
      app.router.push('/events/12');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      expect(app.followed, 1);
      expect(find.text('Sign in to continue'), findsNothing);
    });

    testWidgets('signed out, it asks; "Not now" leaves things as they were',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      app.router.push('/events/12');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Sign in to follow clubs.'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(app.followed, 0);
      expect(find.text('event 12'), findsOneWidget);
      expect(app.pending.location, isNull);
    });

    testWidgets('"Sign in" opens sign-in over the page, to come back to it',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      app.router.push('/events/12');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('sign in'), findsOneWidget);
      expect(app.location, signInLocation('/events/12'));
      expect(app.pending.location, '/events/12');
      expect(app.followed, 0);

      // Signed in, the flow lands on Home and the event opens again.
      app.auth.set(_signedIn);
      app.router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('event 12'), findsOneWidget);
    });
  });

  group('SignInRequired', () {
    testWidgets('shows the screen to someone signed in, and asks anyone else',
        (tester) async {
      final auth = _FakeAuth(_signedOut);
      final container = ProviderContainer(
          overrides: [authStateProvider.overrideWith((ref) => auth)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SignInRequired(
            title: 'Your team',
            message: 'Sign in to see your team.',
            child: Text('the team'),
          ),
        ),
      ));

      expect(find.text('Sign in to see your team.'), findsOneWidget);
      expect(find.text('the team'), findsNothing);

      auth.set(_signedIn);
      await tester.pump();
      expect(find.text('the team'), findsOneWidget);
    });
  });

  group('an event or a club from its website slug', () {
    Future<_FakeTargets> pumpEvent(WidgetTester tester, String eventRef,
        {_FakeTargets? targets}) async {
      final fake = targets ?? _FakeTargets(events: {'hack-night-04': 12});
      final container = ProviderContainer(overrides: [
        linkTargetsProvider.overrideWithValue(fake),
        linkLauncherProvider.overrideWithValue((uri) async => true),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: EventRefPage(
            eventRef: eventRef,
            page: (id) => Text('event page $id'),
          ),
        ),
      ));
      return fake;
    }

    testWidgets('an id opens the page at once, asking nothing',
        (tester) async {
      final fake = await pumpEvent(tester, '12');
      expect(find.text('event page 12'), findsOneWidget);
      expect(fake.asked, 0);
    });

    testWidgets('a slug is looked up, then the page opens', (tester) async {
      await pumpEvent(tester, 'hack-night-04');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('event page 12'), findsOneWidget);
    });

    testWidgets('a slug that names nothing says so, with the website',
        (tester) async {
      await pumpEvent(tester, 'no-such-event');
      await tester.pumpAndSettle();
      expect(find.text('We couldn\'t find that event'), findsOneWidget);
      expect(find.text('Open in browser'), findsOneWidget);
      expect(find.textContaining('no-such-event'), findsNothing);
    });

    testWidgets('a file name is not looked up at all', (tester) async {
      final fake = await pumpEvent(tester, 'rss.xml');
      await tester.pumpAndSettle();
      expect(find.text('We couldn\'t find that event'), findsOneWidget);
      expect(fake.asked, 0);
    });

    testWidgets('offline, it offers a retry', (tester) async {
      final fake = _FakeTargets(
        events: {'hack-night-04': 12},
        error: const ApiException(
            message: 'No connection', type: ApiExceptionType.network),
      );
      await pumpEvent(tester, 'hack-night-04', targets: fake);
      await tester.pumpAndSettle();
      expect(find.text('Try Again'), findsOneWidget);

      fake.error = null;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('event page 12'), findsOneWidget);
    });

    testWidgets('a club by slug gets its id, slug and name', (tester) async {
      final container = ProviderContainer(overrides: [
        linkTargetsProvider.overrideWithValue(_FakeTargets(clubs: {
          'circuit-society': const LinkedClub(
              id: 7, name: 'Circuit Society', slug: 'circuit-society'),
        })),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ClubRefPage(
            clubRef: 'circuit-society',
            page: (id, slug, name) => Text('club $id $slug $name'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('club 7 circuit-society Circuit Society'),
          findsOneWidget);
    });
  });

  group('a link the app cannot show', () {
    testWidgets('is a friendly page that offers the website and home',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      app.router.push('/events/12');
      await tester.pumpAndSettle();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: app.container,
        child: const MaterialApp(
          home: LinkNotFoundPage(location: '/events/x/y?z=1'),
        ),
      ));

      expect(find.text('This page isn\'t in the app'), findsOneWidget);
      // Never the address, never an error's words.
      expect(find.textContaining('/events/x/y'), findsNothing);
      expect(find.textContaining('not found:'), findsNothing);

      await tester.tap(find.text('Open in browser'));
      expect(app.opened.single.toString(),
          'https://myotherapp.in/events/x/y?z=1');
      expect(find.text('Go to Home'), findsOneWidget);
    });

    testWidgets('a certificate, signed out, is its public page',
        (tester) async {
      final app = _App(_signedOut);
      await app.pump(tester);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: app.container,
        child: const MaterialApp(
          home: CertificateLinkPage(ticketId: 'abc-123'),
        ),
      ));

      await tester.tap(find.text('View certificate'));
      expect(app.opened.single.toString(),
          'https://myotherapp.in/certificates/abc-123');
    });
  });
}
