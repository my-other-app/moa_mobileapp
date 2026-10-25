import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/profile_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_details_page.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_final_page.dart';
import 'package:finnet/features/auth/presentation/pages/profile_check_page.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart'
    hide Organization;
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart' show RouteAdapter, useFakeApi;
import 'auth_fakes.dart';

/// The profile the app keeps: [picture] or none.
class _Profiles implements ProfileRepository {
  _Profiles({this.picture});

  final String? picture;

  @override
  Future<UserProfile?> getSavedProfile() async => null;

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(UserProfile(
        id: '7',
        fullName: 'Asha Menon',
        email: 'asha@example.com',
        avatar: picture == null
            ? null
            : Avatar(id: 1, name: 'Fox', image: ImageUrls(original: picture!)),
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// Where a step went next, and what it took along.
typedef _Landed = ({String location, Object? extra});

/// [page] at [start], with the steps it can go to recorded instead of built.
Future<List<_Landed>> _pumpStep(
  WidgetTester tester, {
  required String start,
  required Widget Function(GoRouterState state) page,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = const Size(1200, 2600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final landed = <_Landed>[];
  Widget landing(GoRouterState state) {
    landed.add((location: state.uri.toString(), extra: state.extra));
    return Scaffold(body: Text('landed on ${state.uri.path}'));
  }

  final startPath = Uri.parse(start).path;
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/', builder: (_, s) => landing(s)),
      GoRoute(path: startPath, builder: (_, s) => page(s)),
      for (final path in [
        '/onboarding/details',
        '/onboarding/interests',
        '/clubs/tinkerhub',
        '/auth/onboarding',
      ])
        if (path != startPath)
          GoRoute(path: path, builder: (_, s) => landing(s)),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  return landed;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Answers `/user/profile/me` with [body].
class _Me implements HttpClientAdapter {
  _Me(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(body, 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  group('the profile check, just after signing in', () {
    Future<List<_Landed>> pumpCheck(WidgetTester tester, String me,
        {String start = '/auth/profile-check'}) {
      final service = ProfileService(
          dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = _Me(me));
      return _pumpStep(
        tester,
        start: start,
        page: (_) => ProfileCheckPage(
          accessToken: 'access-1',
          profileUrl: '',
          profileService: service,
        ),
        overrides: [
          secureStorageServiceProvider.overrideWithValue(MemoryStorage(
              {'access_token': 'access-1', 'refresh_token': 'refresh-1'})),
          authSeedProvider.overrideWithValue(const AuthState(
            isInitialized: true,
          )),
          pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
          sessionCachesProvider.overrideWithValue(FakeSessionCaches()),
          profileRepositoryProvider.overrideWithValue(_Profiles()),
        ],
      );
    }

    testWidgets(
        'a new account (no profile yet) goes on to the details, its name '
        'carried -- 1.0.1 skipped this step', (tester) async {
      final landed = await pumpCheck(
          tester, '{"id": 7, "full_name": "Asha Menon", "profile": null}');
      await _settle(tester);

      expect(landed.single.location, '/onboarding/details');
      expect(landed.single.extra,
          {'profileUrl': '', 'initialName': 'Asha Menon'});
    });

    testWidgets('an account with a profile goes home, not to the details',
        (tester) async {
      final landed = await pumpCheck(tester,
          '{"id": 7, "full_name": "Asha Menon", "profile": {"id": 3}}');
      await _settle(tester);

      expect(landed.single.location, '/');
    });

    testWidgets('the page that asked for sign-in comes along to the details',
        (tester) async {
      final landed = await pumpCheck(
          tester, '{"id": 7, "full_name": "Asha Menon", "profile": null}',
          start: '/auth/profile-check?from=%2Fclubs%2Ftinkerhub');
      await _settle(tester);

      expect(landed.single.location,
          '/onboarding/details?from=%2Fclubs%2Ftinkerhub');
    });
  });

  group('the details step', () {
    late RouteAdapter api;

    setUp(() {
      api = useFakeApi()
        ..on('GET', '/orgs/list', [
          {'id': 1, 'name': 'CET Trivandrum'},
          {'id': 2, 'name': 'GEC Thrissur'},
        ]);
    });

    Future<List<_Landed>> pumpDetails(WidgetTester tester,
            {String start = '/onboarding/details'}) =>
        _pumpStep(
          tester,
          start: start,
          page: (_) => const OnboardingDetailsPage(
            initialName: 'Asha Menon',
            profileUrl: '',
          ),
        );

    Future<void> tapContinue(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _settle(tester);
    }

    Finder field(String hint) => find.widgetWithText(TextFormField, hint);

    testWidgets(
        'asks for the name (filled from the account), the college and '
        'WhatsApp, both optional', (tester) async {
      await pumpDetails(tester);
      await _settle(tester);

      expect(find.text('Slide in your deets!'), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Asha Menon');
      expect(find.text('Organization (Optional)'), findsOneWidget);
      expect(find.text('WhatsApp Number (Optional)'), findsOneWidget);
      expect(api.sent('GET', '/orgs/list'), hasLength(1));
    });

    testWidgets(
        'with just a name: the profile is made with only the name, then on '
        'to the interests', (tester) async {
      api.on('POST', '/user/profile/create', {'id': 3});
      final landed = await pumpDetails(tester);
      await _settle(tester);
      await tapContinue(tester);

      final sent = api.sent('POST', '/user/profile/create').single;
      expect(sent.data, {'full_name': 'Asha Menon'});
      expect(sent.contentType, Headers.formUrlEncodedContentType);
      expect(landed.single.location, '/onboarding/interests');
      expect(landed.single.extra, {'isOnboarding': true});
    });

    testWidgets('a college and a WhatsApp number go along', (tester) async {
      api.on('POST', '/user/profile/create', {'id': 3});
      final landed = await pumpDetails(tester);
      await _settle(tester);

      await tester.tap(find.text('Search Your Organization'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GEC Thrissur').last);
      await tester.pumpAndSettle();
      await tester.enterText(field('Enter your WhatsApp number'), '9876543210');
      await tapContinue(tester);

      expect(api.sent('POST', '/user/profile/create').single.data, {
        'full_name': 'Asha Menon',
        'whatsapp': '9876543210',
        'org_id': '2',
      });
      expect(landed.single.location, '/onboarding/interests');
    });

    testWidgets('a name is needed: nothing is sent without one',
        (tester) async {
      final landed = await pumpDetails(tester);
      await _settle(tester);
      await tester.enterText(field('Enter your name'), '   ');
      await tapContinue(tester);

      expect(find.text('Please enter your name'), findsOneWidget);
      expect(api.sent('POST', '/user/profile/create'), isEmpty);
      expect(landed, isEmpty);
    });

    testWidgets(
        'a WhatsApp number must be ten digits; letters cannot be typed',
        (tester) async {
      await pumpDetails(tester);
      await _settle(tester);
      await tester.enterText(field('Enter your WhatsApp number'), '98a765');
      expect(
          tester
              .widget<TextFormField>(field('Enter your WhatsApp number'))
              .controller!
              .text,
          '98765');
      await tapContinue(tester);

      expect(find.text('Please enter a valid 10-digit number'), findsOneWidget);
      expect(api.sent('POST', '/user/profile/create'), isEmpty);
    });

    testWidgets('a profile made on an earlier try carries on to the interests',
        (tester) async {
      api.on(
          'POST',
          '/user/profile/create',
          {
            'message': 'A profile already exists for this account',
            'error_code': 'PROFILE_EXISTS',
          },
          status: 400);
      final landed = await pumpDetails(tester);
      await _settle(tester);
      await tapContinue(tester);

      expect(landed.single.location, '/onboarding/interests');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('any other refusal says why, in its words, and stays',
        (tester) async {
      api.on('POST', '/user/profile/create',
          {'message': 'Invalid WhatsApp number'},
          status: 400);
      final landed = await pumpDetails(tester);
      await _settle(tester);
      await tapContinue(tester);

      expect(find.text('Invalid WhatsApp number'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(landed, isEmpty);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('the page that asked for sign-in comes along to the interests',
        (tester) async {
      api.on('POST', '/user/profile/create', {'id': 3});
      final landed = await pumpDetails(tester,
          start: '/onboarding/details?from=%2Fclubs%2Ftinkerhub');
      await _settle(tester);
      await tapContinue(tester);

      expect(landed.single.location,
          '/onboarding/interests?from=%2Fclubs%2Ftinkerhub');
    });
  });

  group("the last step, 'Profile created'", () {
    Future<List<_Landed>> pumpFinal(WidgetTester tester,
            {String? picture, String start = '/onboarding/complete'}) =>
        _pumpStep(
          tester,
          start: start,
          page: (_) => const OnboardingFinalPage(),
          overrides: [
            profileRepositoryProvider
                .overrideWithValue(_Profiles(picture: picture)),
          ],
        );

    testWidgets('says the profile is made and shows the picture picked',
        (tester) async {
      await pumpFinal(tester, picture: 'https://cdn.test/avatars/fox.png');
      await _settle(tester);

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('CREATED'), findsOneWidget);
      expect(find.text("LET'S GO!"), findsOneWidget);
      expect(find.text('START THE JOURNEY'), findsOneWidget);
    });

    testWidgets('with a picture, START THE JOURNEY goes home', (tester) async {
      final landed =
          await pumpFinal(tester, picture: 'https://cdn.test/avatars/fox.png');
      await _settle(tester);
      await tester.tap(find.text('START THE JOURNEY'));
      await _settle(tester);

      expect(landed.single.location, '/');
    });

    testWidgets('...or back to the page that asked for sign-in',
        (tester) async {
      final landed = await pumpFinal(tester,
          picture: 'https://cdn.test/avatars/fox.png',
          start: '/onboarding/complete?from=%2Fclubs%2Ftinkerhub');
      await _settle(tester);
      await tester.tap(find.text('START THE JOURNEY'));
      await _settle(tester);

      expect(landed.single.location, '/clubs/tinkerhub');
    });

    testWidgets('without a picture it asks for one first', (tester) async {
      final landed = await pumpFinal(tester);
      await _settle(tester);
      await tester.tap(find.text('START THE JOURNEY'));
      await _settle(tester);

      expect(find.text('select profile pic to proceed'), findsOneWidget);
      expect(landed, isEmpty);
    });
  });
}
