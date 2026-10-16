import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/widgets/email_verification_banner.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Profiles implements ProfileRepository {
  final bool? emailVerified;

  _Profiles(this.emailVerified);

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(UserProfile(
        id: '7',
        fullName: 'Asha Rao',
        email: 'asha@example.com',
        emailVerified: emailVerified,
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _banner = ValueKey('email-verification-banner');
const _text = 'Verify your email to bring in tickets you booked on the website';

Future<void> _pump(WidgetTester tester, bool? emailVerified) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Column(children: [EmailVerificationBanner()]),
        ),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) =>
            Text('Verify ${(state.extra as Map)['email']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(_Profiles(emailVerified)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('an unverified email account is asked, and the tap opens Verify',
      (tester) async {
    await _pump(tester, false);

    expect(find.text(_text), findsOneWidget);
    await tester.tap(find.byKey(_banner));
    await tester.pumpAndSettle();
    expect(find.text('Verify asha@example.com'), findsOneWidget);
  });

  testWidgets('closing it hides it', (tester) async {
    await _pump(tester, false);

    await tester.tap(find.byKey(const ValueKey('email-verification-banner-close')));
    await tester.pump();

    expect(find.byKey(_banner), findsNothing);
  });

  testWidgets('verified accounts (Google and Apple ones always) see nothing',
      (tester) async {
    await _pump(tester, true);
    expect(find.byKey(_banner), findsNothing);
  });

  testWidgets('nor does anyone when the server did not say', (tester) async {
    await _pump(tester, null);
    expect(find.byKey(_banner), findsNothing);
  });

  test('the profile reads email_verified, and its absence is "unknown"', () {
    UserProfile from(Map<String, dynamic> json) =>
        UserProfileModel.fromJson({'id': 1, 'email': 'a@b.co', ...json}).toEntity();

    expect(from({'email_verified': false}).needsEmailVerification, isTrue);
    expect(from({'email_verified': true}).needsEmailVerification, isFalse);
    expect(from({}).emailVerified, isNull);
    expect(from({}).needsEmailVerification, isFalse);
  });
}
