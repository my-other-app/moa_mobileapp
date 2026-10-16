import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/data/services/email_verification_service.dart';
import 'package:finnet/features/auth/presentation/pages/verify_email_page.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'email_verification_fakes.dart';

class _FakeProfiles implements ProfileRepository {
  int loads = 0;

  @override
  Future<Result<UserProfile>> getMyProfile() async {
    loads++;
    return Either.right(const UserProfile(
      id: '1',
      fullName: 'Asha Rao',
      email: 'asha@example.com',
      emailVerified: true,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _input = ValueKey('code-input');

/// The page inside a router with the places it can lead: the profile check
/// (onboarding) or back to wherever it was opened from (signed in).
Future<_FakeProfiles> _pump(
  WidgetTester tester, {
  required bool onboarding,
  required FakeEmailVerificationService service,
}) async {
  final profiles = _FakeProfiles();
  final router = GoRouter(
    initialLocation: onboarding ? '/auth/verify-email' : '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/auth/verify-email'),
              child: const Text('Home: open verify'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) => VerifyEmailPage(
          email: 'asha@example.com',
          onboarding: onboarding,
          accessToken: 'access-1',
          profileUrl: 'https://pic',
          service: service,
        ),
      ),
      GoRoute(
        path: '/auth/profile-check',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return Scaffold(
            body: Text(
                'Profile check ${extra['accessToken']} ${extra['profileUrl']}'),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  if (!onboarding) {
    await tester.tap(find.text('Home: open verify'));
    await tester.pumpAndSettle();
  }
  // The post-frame start.
  await tester.pump();
  return profiles;
}

void main() {
  late FakeEmailVerificationService service;

  setUp(() => service = FakeEmailVerificationService());

  testWidgets('says where the code went', (tester) async {
    await _pump(tester, onboarding: true, service: service);

    expect(
      find.textContaining('We sent a 6-digit code to asha@example.com',
          findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Verify later'), findsOneWidget);
  });

  testWidgets(
      'after sign-up it does not send again: resend counts down from a minute',
      (tester) async {
    await _pump(tester, onboarding: true, service: service);

    expect(service.sendCalls, 0);
    expect(find.text('Resend code in 1:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend code in 0:59'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text("Didn't get it? Resend code"), findsOneWidget);

    service.nextSend =
        const EmailCodeSent(email: 'asha@example.com', expiresIn: 900, retryAfter: 90);
    await tester.tap(find.text("Didn't get it? Resend code"));
    await tester.pump();
    expect(service.sendCalls, 1);
    expect(find.text('Resend code in 1:30'), findsOneWidget);
  });

  testWidgets('a resend the server refuses waits for its retry_after',
      (tester) async {
    service.nextSend = const EmailVerificationException(
      EmailVerificationErrorKind.throttled,
      'We just sent you a code. You can ask for another in 42 seconds.',
      retryAfter: 42,
    );
    await _pump(tester, onboarding: false, service: service);

    expect(service.sendCalls, 1);
    expect(find.text('Resend code in 0:42'), findsOneWidget);
    expect(find.textContaining('ask for another in 42 seconds'), findsOneWidget);
  });

  testWidgets('a wrong code says how many tries are left and clears the boxes',
      (tester) async {
    service.nextVerify = const EmailVerificationException(
      EmailVerificationErrorKind.wrongCode,
      "That code isn't right. 4 tries left.",
      attemptsLeft: 4,
    );
    await _pump(tester, onboarding: true, service: service);

    await tester.enterText(find.byKey(_input), '000000');
    await tester.pump();
    await tester.pump();

    expect(service.verified, ['000000']);
    expect(find.text("That code isn't right. 4 tries left."), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text, isEmpty);

    // Typing again clears the message.
    await tester.enterText(find.byKey(_input), '1');
    await tester.pump();
    expect(find.text("That code isn't right. 4 tries left."), findsNothing);
  });

  testWidgets('too many wrong tries: no more codes until a new one is sent',
      (tester) async {
    service.nextVerify = const EmailVerificationException(
      EmailVerificationErrorKind.tooManyAttempts,
      'Too many wrong tries. Ask for a new code.',
      attemptsLeft: 0,
    );
    await _pump(tester, onboarding: true, service: service);

    await tester.enterText(find.byKey(_input), '000000');
    await tester.pump();
    await tester.pump();
    expect(find.text('Too many wrong tries. Ask for a new code.'), findsOneWidget);

    await tester.enterText(find.byKey(_input), '123456');
    await tester.pump();
    expect(service.verified, ['000000']);
  });

  testWidgets('verified after sign-up: on to the profile check as before',
      (tester) async {
    service.nextVerify =
        const EmailVerifiedResult(merged: true, registrationsTransferred: 1);
    await _pump(tester, onboarding: true, service: service);

    await tester.enterText(find.byKey(_input), '123456');
    await tester.pumpAndSettle();

    expect(service.verified, ['123456']);
    expect(find.text('Profile check access-1 https://pic'), findsOneWidget);
    expect(find.textContaining('1 ticket from the website is now in your account'),
        findsOneWidget);
  });

  testWidgets('"Verify later" after sign-up carries on to the profile check',
      (tester) async {
    await _pump(tester, onboarding: true, service: service);

    await tester.tap(find.text('Verify later'));
    await tester.pumpAndSettle();

    expect(service.verified, isEmpty);
    expect(find.text('Profile check access-1 https://pic'), findsOneWidget);
  });

  testWidgets(
      'opened from the banner: asks for a code, and on success reloads the '
      'profile and goes back', (tester) async {
    final profiles = await _pump(tester, onboarding: false, service: service);
    expect(service.sendCalls, 1);
    final loadsBefore = profiles.loads;

    await tester.enterText(find.byKey(_input), '654321');
    await tester.pumpAndSettle();

    expect(find.text('Home: open verify'), findsOneWidget);
    expect(find.text('Email verified.'), findsOneWidget);
    expect(profiles.loads, greaterThan(loadsBefore));
  });

  testWidgets('opened from the banner, "Verify later" just goes back',
      (tester) async {
    await _pump(tester, onboarding: false, service: service);

    await tester.tap(find.text('Verify later'));
    await tester.pumpAndSettle();

    expect(find.text('Home: open verify'), findsOneWidget);
    expect(service.verified, isEmpty);
  });
}
