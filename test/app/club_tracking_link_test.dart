// A club's tracking link -- myotherapp.in/clubs/{slug}?ref=... on a poster,
// a QR, a WhatsApp message -- opens that club in the app, signed in or not,
// with the ref still on the location. (Nothing in the app reads or reports
// the ref yet: app opens are not counted the way the website counts them.)

import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/clubs/presentation/pages/club_individual_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

GoRouter _routerFor(AuthState auth) {
  final container = ProviderContainer(overrides: [
    authStateProvider.overrideWith((ref) => _FakeAuth(auth)),
    routerObserversProvider.overrideWithValue(const []),
  ]);
  addTearDown(container.dispose);
  return container.read(routerProvider);
}

/// Where [link] lands, redirects and all, and the screen built there.
Future<(GoRouterState, Widget)> _open(
    WidgetTester tester, GoRouter router, String link) async {
  await tester.pumpWidget(const SizedBox());
  final context = tester.element(find.byType(SizedBox));
  final matches = await Future.value(router.configuration.redirect(
    context,
    router.configuration.findMatch(Uri.parse(link)),
    redirectHistory: [],
  ));
  expect(matches.isError, isFalse, reason: '$link matched no route');
  final leaf = matches.matches.last;
  final route = leaf.route as GoRoute;
  final state = leaf.buildState(router.configuration, matches);
  return (state, route.builder!(context, state));
}

void main() {
  for (final (who, auth) in [
    ('signed in', _signedIn),
    ('signed out', _signedOut),
  ]) {
    testWidgets('$who, the link opens the club by its slug, ref and all',
        (tester) async {
      final (state, page) = await _open(tester, _routerFor(auth),
          'https://myotherapp.in/clubs/circuit-society?ref=qr-poster');

      expect(state.name, AppRoutes.clubDetail);
      expect(state.uri.path, '/clubs/circuit-society');
      expect(state.uri.queryParameters['ref'], 'qr-poster');
      // A slug alone is enough: the page reads the club by it.
      expect(
          page,
          isA<ClubIndividualPage>()
              .having((p) => p.clubSlug, 'clubSlug', 'circuit-society')
              .having((p) => p.clubId, 'clubId', 0));
    });
  }

  testWidgets('www. and a link by the club\'s id land on the same screen',
      (tester) async {
    final router = _routerFor(_signedIn);

    final (byWww, wwwPage) = await _open(tester, router,
        'https://www.myotherapp.in/clubs/circuit-society?ref=wa');
    expect(byWww.uri.queryParameters['ref'], 'wa');
    expect((wwwPage as ClubIndividualPage).clubSlug, 'circuit-society');

    final (byId, idPage) =
        await _open(tester, router, 'https://myotherapp.in/clubs/42?ref=wa');
    expect(byId.uri.queryParameters['ref'], 'wa');
    expect(
        idPage,
        isA<ClubIndividualPage>()
            .having((p) => p.clubId, 'clubId', 42)
            .having((p) => p.clubSlug, 'clubSlug', ''));
  });

  testWidgets(
      'from the phone (an App Link or Universal Link), the same location, '
      'with Home under the club so Back leads into the app', (tester) async {
    final location = appLocationForLink(
        Uri.parse('https://myotherapp.in/clubs/circuit-society?ref=qr'));
    expect(location, '/clubs/circuit-society?ref=qr');

    final router = _routerFor(_signedOut);
    final (state, page) = await _open(tester, router, location!);
    expect(state.uri.queryParameters['ref'], 'qr');
    expect((page as ClubIndividualPage).clubSlug, 'circuit-society');
    expect([
      for (final route in router.configuration
          .findMatch(Uri.parse(location))
          .routes)
        if (route is GoRoute) route.name,
    ], [
      'home',
      AppRoutes.clubDetail
    ]);
  });
}
