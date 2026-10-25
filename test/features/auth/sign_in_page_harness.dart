import 'package:finnet/features/auth/data/services/apple_auth_service.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';

/// Where a sign-in went next, and what it took along.
typedef Landed = ({String page, Map<String, dynamic>? extra});

/// A phone without Apple's sign-in (Android): no button, and nothing ever
/// reaches the platform.
final noApple = AppleSignIn(
  isAvailable: () async => false,
  credential: () => throw StateError('Apple sign-in is not offered here'),
);

/// The sign-in screen as the app routes it, with the two places a sign-in
/// goes next recorded instead of built.
///
/// Wide: the buttons' labels are measured in the test font, where every
/// glyph is a full em, so "LOGIN WITH GOOGLE" would not fit a phone.
Future<List<Landed>> pumpSignIn(
  WidgetTester tester, {
  GoogleSignIn? google,
  AppleSignIn? apple,
}) async {
  tester.view
    ..physicalSize = const Size(1200, 2600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final landed = <Landed>[];
  Widget landing(String page, GoRouterState state) {
    landed.add((page: page, extra: state.extra as Map<String, dynamic>?));
    return Scaffold(body: Text('landed on $page'));
  }

  final router = GoRouter(
    initialLocation: '/auth/onboarding',
    routes: [
      GoRoute(
        path: '/auth/onboarding',
        builder: (_, __) => OnboardingInitialPage(
          googleSignIn: google,
          appleSignIn: apple ?? noApple,
        ),
      ),
      GoRoute(
        path: '/auth/profile-check',
        builder: (_, state) => landing('profile-check', state),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (_, state) => landing('verify-email', state),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pump();
  return landed;
}

/// A few frames: the request, its answer, the tokens stored, the route.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
