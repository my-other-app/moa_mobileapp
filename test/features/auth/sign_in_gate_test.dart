import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/profile_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/pages/profile_check_page.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'auth_fakes.dart';

/// A page with something on it that needs an account.
class _ClubPage extends ConsumerWidget {
  const _ClubPage({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          Text('club $id'),
          ElevatedButton(
            onPressed: () {
              if (ensureSignedIn(context, ref, 'Sign in to follow clubs.')) {
                ref.read(_followed.notifier).state = true;
              }
            },
            child: const Text('FOLLOW'),
          ),
          ElevatedButton(
            onPressed: () => showSignInPrompt(
                context, ref, 'Your session has expired. Sign in again.'),
            child: const Text('EXPIRED'),
          ),
        ],
      ),
    );
  }
}

final _followed = StateProvider<bool>((ref) => false);

/// Stands in for the sign-in screen: shows the address it was opened at,
/// and its button finishes signing in the way the last step does.
class _SignIn extends ConsumerWidget {
  const _SignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          Text('sign-in at ${GoRouterState.of(context).uri}'),
          ElevatedButton(
            onPressed: () => goAfterSignIn(context, signInFromOf(context)),
            child: const Text('SIGNED IN'),
          ),
        ],
      ),
    );
  }
}

Widget _stub(String label) => Builder(
    builder: (context) => Text('$label ${GoRouterState.of(context).uri}'));

GoRouter _router({String initial = '/clubs/12'}) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(
            path: '/clubs/:id',
            builder: (context, state) =>
                _ClubPage(id: state.pathParameters['id']!)),
        GoRoute(path: '/auth/onboarding', builder: (_, __) => const _SignIn()),
        GoRoute(
          path: '/auth/profile-check',
          builder: (context, state) => ProfileCheckPage(
            accessToken: 'access',
            profileUrl: '',
            profileService: _profiles,
          ),
        ),
        GoRoute(
            path: '/onboarding/details',
            builder: (_, __) => Scaffold(body: _stub('details at'))),
      ],
    );

late ProfileService _profiles;

/// `/user/profile/me` answers [body].
ProfileService _profileAnswering(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _Answer(body)
    ..interceptors.add(ErrorInterceptor());
  return ProfileService(dio: dio);
}

class _Answer implements HttpClientAdapter {
  _Answer(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

class _FakeProfiles implements ProfileRepository {
  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(
      const UserProfile(id: '7', fullName: 'Asha', email: 'a@b.co'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

Future<ProviderContainer> _pump(WidgetTester tester,
    {required bool signedIn, GoRouter? router, bool realAuth = false}) async {
  final container = ProviderContainer(overrides: [
    if (!realAuth) isAuthenticatedProvider.overrideWithValue(signedIn),
    secureStorageServiceProvider
        .overrideWithValue(MemoryStorage({'access_token': 'access'})),
    pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
    sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
    sessionCachesProvider.overrideWithValue(FakeSessionCaches()),
    profileRepositoryProvider.overrideWithValue(_FakeProfiles()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router ?? _router()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('the page to come back to', () {
    test('only a path of this app is gone back to', () {
      expect(safeReturnPath('/clubs/12'), '/clubs/12');
      expect(safeReturnPath('/events/hack-night?live=room'),
          '/events/hack-night?live=room');
      for (final unsafe in [
        null,
        '',
        'clubs/12',
        '//evil.example/x',
        'https://evil.example',
        'javascript:alert(1)',
        '/\\evil.example',
        // A sign-in step would go round in a circle.
        '/auth/onboarding',
        '/onboarding/details',
        '/splash',
      ]) {
        expect(safeReturnPath(unsafe), isNull, reason: '$unsafe');
      }
    });

    test('carried as ?from=, and only when safe', () {
      expect(withSignInFrom('/auth/profile-check', '/clubs/12'),
          '/auth/profile-check?from=%2Fclubs%2F12');
      expect(withSignInFrom('/onboarding/details', 'https://evil.example'),
          '/onboarding/details');
      expect(
          withSignInFrom('/onboarding/details', null), '/onboarding/details');
    });
  });

  group('asking to sign in', () {
    testWidgets('signed in, the action just happens: no sheet, no sign-out',
        (tester) async {
      final c = await _pump(tester, signedIn: true);

      await tester.tap(find.text('FOLLOW'));
      await tester.pumpAndSettle();

      expect(c.read(_followed), isTrue);
      expect(find.byKey(const ValueKey('sign-in-prompt')), findsNothing);
    });

    testWidgets('signed out, it asks first and does nothing on "Not now"',
        (tester) async {
      final c = await _pump(tester, signedIn: false);

      await tester.tap(find.text('FOLLOW'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sign-in-prompt')), findsOneWidget);
      expect(find.text('Sign in to follow clubs.'), findsOneWidget);
      expect(c.read(_followed), isFalse);

      await tester.tap(find.byKey(const ValueKey('sign-in-prompt-later')));
      await tester.pumpAndSettle();
      expect(find.text('club 12'), findsOneWidget);
    });

    testWidgets('SIGN IN opens /auth/onboarding?from=<this page>',
        (tester) async {
      await _pump(tester, signedIn: false);

      await tester.tap(find.text('FOLLOW'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign-in-prompt-go')));
      await tester.pumpAndSettle();

      expect(find.text('sign-in at /auth/onboarding?from=%2Fclubs%2F12'),
          findsOneWidget);

      // Signing in comes back.
      await tester.tap(find.text('SIGNED IN'));
      await tester.pumpAndSettle();
      expect(find.text('club 12'), findsOneWidget);
    });

    testWidgets("Threads' expired-session prompt asks; it never signs out",
        (tester) async {
      final c = await _pump(tester, signedIn: true, realAuth: true);
      await c
          .read(authStateProvider.notifier)
          .setAuthenticated(accessToken: 'access', refreshToken: 'refresh');
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPIRED'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sign-in-prompt')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sign-in-prompt-later')));
      await tester.pumpAndSettle();
      expect(c.read(authStateProvider).isAuthenticated, isTrue);
    });
  });

  group('the profile check finishes where sign-in started', () {
    testWidgets('an existing account goes back to the page', (tester) async {
      _profiles = _profileAnswering({
        'id': 7,
        'full_name': 'Asha',
        'profile': {'full_name': 'Asha'},
      });
      await _pump(tester,
          signedIn: false,
          router: _router(initial: '/auth/profile-check?from=%2Fclubs%2F12'));

      expect(find.text('club 12'), findsOneWidget);
    });

    testWidgets('an address that is not ours goes home', (tester) async {
      _profiles = _profileAnswering({
        'id': 7,
        'full_name': 'Asha',
        'profile': {'full_name': 'Asha'},
      });
      await _pump(tester,
          signedIn: false,
          router: _router(
              initial: '/auth/profile-check?from=%2F%2Fevil.example%2Fx'));

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a new account carries the page into onboarding',
        (tester) async {
      _profiles = _profileAnswering({'id': 7, 'full_name': 'Asha'});
      await _pump(tester,
          signedIn: false,
          router: _router(initial: '/auth/profile-check?from=%2Fclubs%2F12'));

      expect(find.text('details at /onboarding/details?from=%2Fclubs%2F12'),
          findsOneWidget);
    });
  });
}
