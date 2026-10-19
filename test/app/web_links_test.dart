import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/pending_location.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/widgets.dart';
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

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

void main() {
  group('webLocation: a website link, as an app location', () {
    String? at(String url) => webLocation(Uri.parse(url));

    test('the claimed pages open as they are', () {
      expect(at('https://myotherapp.in/events/hack-night-04'),
          '/events/hack-night-04');
      expect(at('https://myotherapp.in/events/123'), '/events/123');
      expect(at('https://myotherapp.in/clubs/circuit-society'),
          '/clubs/circuit-society');
      expect(at('https://myotherapp.in/threads/7d0f3c2a-1111'),
          '/threads/7d0f3c2a-1111');
      expect(at('https://myotherapp.in/tickets/abc-123'), '/tickets/abc-123');
      expect(at('https://myotherapp.in/certificates/abc-123'),
          '/certificates/abc-123');
      expect(at('https://myotherapp.in/topics/development'),
          '/topics/development');
    });

    test('the live room is the event with its room open', () {
      expect(at('https://myotherapp.in/events/hack-night-04/live'),
          '/events/hack-night-04?live=room');
    });

    test('register and compete open the event, whose page has them', () {
      expect(at('https://myotherapp.in/events/hack-night-04/register'),
          '/events/hack-night-04');
      expect(at('https://myotherapp.in/events/hack-night-04/compete'),
          '/events/hack-night-04');
    });

    test('the query comes along (a club link\'s ref, say)', () {
      expect(at('https://myotherapp.in/clubs/circuit-society?ref=abc'),
          '/clubs/circuit-society?ref=abc');
      expect(at('https://myotherapp.in/events/x/live?utm=push'),
          '/events/x?utm=push&live=room');
    });

    test('www., events. and a bare path are the same site', () {
      expect(at('https://www.myotherapp.in/events/x'), '/events/x');
      expect(at('https://events.myotherapp.in/events/x'), '/events/x');
      expect(at('http://myotherapp.in/events/x'), '/events/x');
      expect(at('/events/x'), '/events/x');
      expect(at('https://MyOtherApp.in/Events/x'), '/events/x');
    });

    test('the old event addresses, the directories and /me', () {
      expect(at('https://myotherapp.in/123'), '/events/123');
      expect(at('https://myotherapp.in/123/live'), '/events/123?live=room');
      expect(at('https://myotherapp.in/events'), '/events/explore');
      expect(at('https://myotherapp.in/events?topic=design'),
          '/events/explore?topic=design');
      expect(at('https://myotherapp.in/clubs'), '/clubs/explore');
      expect(at('https://myotherapp.in/me/tickets'), '/events');
      expect(at('https://myotherapp.in/me/following'), '/clubs');
      expect(at('https://myotherapp.in/'), '/');
      expect(at('https://myotherapp.in'), '/');
    });

    test('anything else is the browser\'s', () {
      for (final url in [
        'https://myotherapp.in/feedback/1/2?k=x',
        'https://myotherapp.in/play/123',
        'https://myotherapp.in/for-clubs',
        'https://myotherapp.in/pricing',
        'https://myotherapp.in/privacy',
        'https://myotherapp.in/about',
        'https://myotherapp.in/events/rss.xml',
        'https://myotherapp.in/clubs/x/rss.xml',
        'https://myotherapp.in/events/x/y/z',
        'https://myotherapp.in/threads/a/b',
        'https://myotherapp.in/media/events/x/poster',
        'https://myotherapp.in/og/events/x',
        'https://myotherapp.in/api/share/x',
        'https://myotherapp.in/hack-night-04',
        'https://circuit.myotherapp.in/events/x',
        'https://example.com/events/x',
        'mailto:support@myotherapp.in',
        '//example.com/events/x',
      ]) {
        expect(at(url), isNull, reason: url);
      }
    });

    test('a path that is not path-safe stays one segment', () {
      expect(at('https://myotherapp.in/threads/a%2Fb'), '/threads/a%2Fb');
    });

    test('websiteUriFor is the site\'s page for an app location', () {
      expect(websiteUriFor('/events/x?live=room').toString(),
          'https://myotherapp.in/events/x?live=room');
      expect(websiteUriFor('/').toString(), 'https://myotherapp.in/');
    });
  });

  group('the router, with the website\'s links', () {
    late _FakeAuth auth;
    late ProviderContainer container;

    GoRouter routerWith(AuthState initial) {
      auth = _FakeAuth(initial);
      container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => auth),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      return container.read(routerProvider);
    }

    /// Where the router ends up for [location], redirects and all.
    Future<String> resolve(
        WidgetTester tester, GoRouter router, String location) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      final match = await Future.value(router.configuration.redirect(
        context,
        router.configuration.findMatch(Uri.parse(location)),
        redirectHistory: [],
      ));
      expect(match.isError, isFalse, reason: '$location matched no route');
      return match.uri.toString();
    }

    testWidgets('every link the website claims reaches a screen',
        (tester) async {
      final router = routerWith(_signedIn);
      for (final url in [
        'https://myotherapp.in/events/hack-night-04',
        'https://myotherapp.in/events/123',
        'https://myotherapp.in/events/hack-night-04/live',
        'https://myotherapp.in/events/hack-night-04/register',
        'https://myotherapp.in/events/hack-night-04/compete',
        'https://myotherapp.in/clubs/circuit-society',
        'https://myotherapp.in/threads/7d0f3c2a-1111-4c4c-9a9a-000000000001',
        'https://myotherapp.in/tickets/abc-123',
        'https://myotherapp.in/certificates/abc-123',
        'https://myotherapp.in/topics/development',
        'https://myotherapp.in/123/live',
        'https://myotherapp.in/events',
        'https://myotherapp.in/me/tickets',
      ]) {
        await resolve(tester, router, webLocation(Uri.parse(url))!);
      }
    });

    testWidgets('the website\'s own paths open too, as Android hands them over',
        (tester) async {
      final router = routerWith(_signedIn);
      expect(await resolve(tester, router, '/events/hack-night-04/live'),
          '/events/hack-night-04?live=room');
      expect(await resolve(tester, router, '/events/hack-night-04/compete'),
          '/events/hack-night-04');
      expect(await resolve(tester, router, '/topics/development'),
          '/events/explore?topic=development');
      // From a link, registering starts at the event: the form needs the
      // questions the event's page hands over.
      expect(await resolve(tester, router, '/events/hack-night-04/register'),
          '/events/hack-night-04');
    });

    testWidgets('signed out, a public link opens and a private one asks first',
        (tester) async {
      final router = routerWith(_signedOut);
      expect(await resolve(tester, router, '/events/hack-night-04'),
          '/events/hack-night-04');
      expect(await resolve(tester, router, '/tickets/abc-123'),
          '/tickets/abc-123');
      expect(await resolve(tester, router, '/profile/notifications'),
          signInLocation('/profile/notifications'));
    });

    testWidgets('a link that opens the app waits for the splash screen',
        (tester) async {
      final router = routerWith(const AuthState());
      final pending = container.read(pendingLocationProvider);

      expect(await resolve(tester, router, '/events/hack-night-04'), '/splash');
      expect(pending.location, '/events/hack-night-04');
      expect(pending.fromLaunch, isTrue);

      // The splash finds nobody signed in and sends them to sign-in: the
      // public link opens over Home instead.
      auth.set(_signedOut);
      expect(await resolve(tester, router, '/auth/onboarding'), '/');
    });

    testWidgets('a private link that opens the app asks for sign-in first',
        (tester) async {
      final router = routerWith(const AuthState());
      expect(await resolve(tester, router, '/profile/settings'), '/splash');
      auth.set(_signedOut);
      expect(await resolve(tester, router, '/auth/onboarding'),
          signInLocation('/profile/settings'));
    });

    testWidgets('the splash and the sign-in screen are never held as links',
        (tester) async {
      final router = routerWith(const AuthState());
      final pending = container.read(pendingLocationProvider);
      await resolve(tester, router, '/splash');
      await resolve(tester, router, '/');
      await resolve(tester, router, '/auth/onboarding');
      expect(pending.location, isNull);
    });
  });

  test('isTabRoot names the bottom bar\'s pages', () {
    expect(isTabRoot('/'), isTrue);
    expect(isTabRoot('/profile'), isTrue);
    expect(isTabRoot('/profile/settings'), isFalse);
    expect(isTabRoot('/events/12'), isFalse);
  });
}
