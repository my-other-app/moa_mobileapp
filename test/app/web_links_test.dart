import 'dart:io';

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

    test('the live room opens the app\'s own room', () {
      expect(at('https://myotherapp.in/events/hack-night-04/live'),
          '/events/hack-night-04/live');
      // The website's quiz page: the app's quiz.
      expect(at('https://myotherapp.in/play/123'), '/events/123/live/quiz');
    });

    test('registration, the competition and the survey open as they are', () {
      expect(at('https://myotherapp.in/events/hack-night-04/register'),
          '/events/hack-night-04/register');
      expect(at('https://myotherapp.in/events/hack-night-04/compete'),
          '/events/hack-night-04/compete');
      expect(at('https://myotherapp.in/feedback/12/34?k=abc'),
          '/feedback/12/34?k=abc');
    });

    test('the directories are batch A\'s Discover screens, filters and all',
        () {
      // The app's own /events and /clubs are the person's (the tabs).
      expect(at('https://myotherapp.in/events'), '/discover/events');
      expect(
          at('https://myotherapp.in/events?when=this_week&price=free&near=9.9,76.3'),
          '/discover/events?when=this_week&price=free&near=9.9%2C76.3');
      expect(at('https://myotherapp.in/events?view=calendar&month=2026-11'),
          '/discover/events?view=calendar&month=2026-11');
      expect(at('https://myotherapp.in/clubs?topic=design&sort=nearby'),
          '/discover/clubs?topic=design&sort=nearby');
      expect(at('https://myotherapp.in/threads'), '/discover/threads');
      expect(at('https://myotherapp.in/topics'), '/topics');
      expect(at('https://myotherapp.in/topics/development?interest=12'),
          '/topics/development?interest=12');
    });

    test('the city pages are the directories, never an event called "in"', () {
      expect(at('https://myotherapp.in/events/in'), '/discover/events');
      expect(at('https://myotherapp.in/events/in/kochi'), '/discover/events');
      expect(at('https://myotherapp.in/events/IN/Kochi?utm=wa'),
          '/discover/events?utm=wa');
      expect(at('https://myotherapp.in/clubs/in'), '/discover/clubs');
      expect(at('https://myotherapp.in/clubs/in/thrissur'), '/discover/clubs');
      // A city's feed is still a file, and deeper paths the browser's.
      expect(at('https://myotherapp.in/events/in/kochi/rss.xml'), isNull);
      expect(at('https://myotherapp.in/events/in/kochi/x'), isNull);
      // An event whose slug starts with "in" is still that event.
      expect(at('https://myotherapp.in/events/intro-night-a1b2c3'),
          '/events/intro-night-a1b2c3');
    });

    test('the query comes along (a club link\'s ref, say)', () {
      expect(at('https://myotherapp.in/clubs/circuit-society?ref=abc'),
          '/clubs/circuit-society?ref=abc');
      expect(at('https://myotherapp.in/events/x/live?utm=push'),
          '/events/x/live?utm=push');
    });

    test('www., events. and a bare path are the same site', () {
      expect(at('https://www.myotherapp.in/events/x'), '/events/x');
      expect(at('https://events.myotherapp.in/events/x'), '/events/x');
      expect(at('http://myotherapp.in/events/x'), '/events/x');
      expect(at('/events/x'), '/events/x');
      expect(at('https://MyOtherApp.in/Events/x'), '/events/x');
    });

    test('the old event addresses and /me', () {
      expect(at('https://myotherapp.in/123'), '/events/123');
      expect(at('https://myotherapp.in/123/live'), '/events/123/live');
      expect(at('https://myotherapp.in/me/tickets'), '/events');
      expect(at('https://myotherapp.in/me/following'), '/clubs');
      expect(at('https://myotherapp.in/'), '/');
      expect(at('https://myotherapp.in'), '/');
    });

    test('anything else is the browser\'s', () {
      for (final url in [
        'https://myotherapp.in/feedback/1',
        'https://myotherapp.in/play/abc',
        'https://myotherapp.in/play',
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

    test(
        'appLocationForLink: a whole URL from the platform, read as the app\'s',
        () {
      String? link(String url) => appLocationForLink(Uri.parse(url));
      expect(link('https://myotherapp.in/events?when=today'),
          '/discover/events?when=today');
      expect(link('https://myotherapp.in/events/x/live'), '/events/x/live');
      // A page of the site the app doesn't have: its path, which the
      // friendly page offers in the browser.
      expect(link('https://myotherapp.in/for-clubs'), '/for-clubs');
      expect(
          link('https://myotherapp.in/events/x/y/z?a=1'), '/events/x/y/z?a=1');
      // Inside the app, or another app's callback: left alone.
      expect(link('/events'), isNull);
      expect(link('com.googleusercontent.apps.x:/oauth2redirect'), isNull);
      expect(link('https://example.com/events/x'), isNull);
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

    const claimed = [
      'https://myotherapp.in/events',
      'https://myotherapp.in/events?when=this_week&type=online',
      'https://myotherapp.in/events/hack-night-04',
      'https://myotherapp.in/events/123',
      'https://myotherapp.in/events/hack-night-04/live',
      'https://myotherapp.in/events/hack-night-04/register',
      'https://myotherapp.in/events/hack-night-04/compete',
      'https://myotherapp.in/clubs',
      'https://myotherapp.in/clubs/circuit-society',
      'https://myotherapp.in/threads',
      'https://myotherapp.in/threads/7d0f3c2a-1111-4c4c-9a9a-000000000001',
      'https://myotherapp.in/tickets/abc-123',
      'https://myotherapp.in/certificates/abc-123',
      'https://myotherapp.in/topics',
      'https://myotherapp.in/topics/development',
      'https://myotherapp.in/feedback/12/34?k=abc',
    ];

    testWidgets(
        'every link the website claims reaches a screen, signed in or not',
        (tester) async {
      for (final start in [_signedIn, _signedOut]) {
        final router = routerWith(start);
        for (final url in claimed) {
          final at = await resolve(tester, router, url);
          expect(at, isNot(startsWith(signInPath)), reason: url);
        }
        // Push links the site doesn't claim, too.
        for (final url in [
          'https://myotherapp.in/123/live',
          'https://myotherapp.in/play/123',
          'https://myotherapp.in/me/tickets',
        ]) {
          await resolve(tester, router, url);
        }
      }
    });

    testWidgets('a link arrives as the whole URL and lands on the app\'s route',
        (tester) async {
      final router = routerWith(_signedIn);
      expect(
          await resolve(
              tester, router, 'https://myotherapp.in/events/hack-night-04'),
          '/events/hack-night-04');
      expect(
          await resolve(tester, router,
              'https://myotherapp.in/events/hack-night-04/live'),
          '/events/hack-night-04/live');
      // The event's page asked for its room, as older links did: the room.
      expect(await resolve(tester, router, '/events/hack-night-04?live=room'),
          '/events/hack-night-04/live');
      expect(await resolve(tester, router, '/events/12?live=quiz'),
          '/events/12/live/quiz');
      expect(
          await resolve(tester, router,
              'https://www.myotherapp.in/clubs/circuit-society?ref=qr'),
          '/clubs/circuit-society?ref=qr');
      expect(
          await resolve(tester, router,
              'https://myotherapp.in/events/hack-night-04/register'),
          '/events/hack-night-04/register');
      // The app's own /events is still the Events tab.
      expect(await resolve(tester, router, '/events'), '/events');
    });

    /// The names of the routes [location] matches, outermost first.
    List<String?> namesAt(GoRouter router, String location) => [
          for (final route
              in router.configuration.findMatch(Uri.parse(location)).routes)
            if (route is GoRoute) route.name,
        ];

    testWidgets('the features\' links open their own screens, over Home',
        (tester) async {
      final router = routerWith(_signedIn);
      expect(await resolve(tester, router, '/events/hack-night-04/compete'),
          '/events/hack-night-04/compete');
      expect(await resolve(tester, router, '/topics/development'),
          '/topics/development');
      expect(await resolve(tester, router, '/topics'), '/topics');
      expect(
          await resolve(tester, router,
              'https://myotherapp.in/events?when=this_week&topic=design'),
          '/discover/events?when=this_week&topic=design');
      expect(await resolve(tester, router, 'https://myotherapp.in/clubs'),
          '/discover/clubs');
      expect(await resolve(tester, router, 'https://myotherapp.in/threads'),
          '/discover/threads');
      expect(await resolve(tester, router, '/feedback/12/34?k=abc'),
          '/feedback/12/34?k=abc');

      // Home is under each, so Back from a link leads into the app; a topic
      // sits on its own, not inside the tabs under the topics list.
      expect(namesAt(router, '/events/hack-night-04/compete'),
          ['home', 'eventCompetition']);
      expect(
          namesAt(router, '/topics/development'), ['home', 'topics', 'topic']);
      expect(namesAt(router, '/discover/clubs'), ['home', 'clubsDirectory']);
      expect(namesAt(router, '/feedback/12/34'), ['home', 'eventFeedback']);
      expect(namesAt(router, '/following/posts').first, 'home');
      expect(namesAt(router, '/verify/certificates/CERT-1').first, 'home');
      expect(namesAt(router, '/events/hack-night-04'), ['home', 'eventDetail']);
      // The live room and its quiz, in the app, under the event.
      expect(namesAt(router, '/events/hack-night-04/live'),
          ['home', 'eventDetail', 'eventLive']);
      expect(namesAt(router, '/events/12/live/quiz'),
          ['home', 'eventDetail', 'eventLive', 'eventLiveQuiz']);
      expect(namesAt(router, '/clubs/circuit-society'), ['home', 'clubDetail']);
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
      // The whole URL from the platform is read first, then asked about.
      expect(await resolve(tester, router, 'https://myotherapp.in/me/tickets'),
          signInLocation('/events'));
    });

    testWidgets('a link that opens the app waits for the splash screen',
        (tester) async {
      final router = routerWith(const AuthState());
      final pending = container.read(pendingLocationProvider);

      expect(
          await resolve(
              tester, router, 'https://myotherapp.in/events/hack-night-04'),
          '/splash');
      // Held as the app's location, not the URL.
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

  test('every path Android hands the app is one it reads', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final paths = RegExp(r'android:path="([^"]+)"')
        .allMatches(manifest)
        .map((m) => m.group(1)!);
    final prefixes = RegExp(r'android:pathPrefix="([^"]+)"')
        .allMatches(manifest)
        .map((m) => m.group(1)!);
    expect(paths, isNotEmpty);
    expect(prefixes, isNotEmpty);
    for (final path in paths) {
      expect(webLocation(Uri.parse('https://myotherapp.in$path')), isNotNull,
          reason: path);
    }
    for (final prefix in prefixes) {
      final sample = switch (prefix) {
        '/feedback/' => '${prefix}12/34',
        // The quiz's QR names the event by its id.
        '/play/' => '${prefix}12',
        _ => '${prefix}x',
      };
      expect(webLocation(Uri.parse('https://myotherapp.in$sample')), isNotNull,
          reason: sample);
    }
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:host="myotherapp.in"'));
  });

  test('Android opens the quiz QR and the live room in the app', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final prefixes = RegExp(r'android:pathPrefix="([^"]+)"')
        .allMatches(manifest)
        .map((m) => m.group(1)!)
        .toList();
    // The big screen's quiz QR: myotherapp.in/play/{event}.
    expect(prefixes, contains('/play/'));
    expect(webLocation(Uri.parse('https://myotherapp.in/play/12')),
        '/events/12/live/quiz');
    // The live room is under /events/, which Android hands the app whole.
    const live = '/events/hack-night-04/live';
    expect(prefixes.any(live.startsWith), isTrue);
    expect(webLocation(Uri.parse('https://myotherapp.in$live')), live);
  });

  test('isTabRoot names the bottom bar\'s pages', () {
    expect(isTabRoot('/'), isTrue);
    expect(isTabRoot('/profile'), isTrue);
    expect(isTabRoot('/profile/settings'), isFalse);
    expect(isTabRoot('/events/12'), isFalse);
  });
}
