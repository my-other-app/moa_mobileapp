import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/apple_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../events/events_fakes.dart' show RouteAdapter, useFakeApi;
import 'sign_in_page_harness.dart';

class _Google extends Mock implements GoogleSignIn {}

class _Account extends Mock implements GoogleSignInAccount {}

class _Tokens extends Mock implements GoogleSignInAuthentication {}

const _photo = 'https://lh3.googleusercontent.test/asha.jpg';

const _tokens = {
  'access_token': 'access-1',
  'refresh_token': 'refresh-1',
  'token_type': 'Bearer',
};

/// Google's account picker: the person picks Asha's account (whose ID token
/// is [idToken]), closes the picker ([cancelled]), or it fails ([fails]).
_Google _google({
  String? idToken = 'google-id-token',
  bool cancelled = false,
  Object? fails,
}) {
  final google = _Google();
  final account = _Account();
  final tokens = _Tokens();
  when(() => tokens.idToken).thenReturn(idToken);
  when(() => account.authentication).thenAnswer((_) async => tokens);
  when(() => account.photoUrl).thenReturn(_photo);
  when(() => google.signIn()).thenAnswer((_) async {
    if (fails != null) throw fails;
    return cancelled ? null : account;
  });
  when(() => google.disconnect()).thenAnswer((_) async => null);
  return google;
}

/// Apple's sheet on an iPhone, giving [credential] or throwing [fails].
AppleSignIn _apple({
  AuthorizationCredentialAppleID? credential,
  Object? fails,
}) =>
    AppleSignIn(
      isAvailable: () async => true,
      credential: () async {
        if (fails != null) throw fails;
        return credential!;
      },
    );

AuthorizationCredentialAppleID _appleId({
  String? givenName = 'Asha',
  String? familyName = 'Menon',
  String? email = 'asha@privaterelay.appleid.com',
}) =>
    AuthorizationCredentialAppleID(
      userIdentifier: '001234.abcd',
      givenName: givenName,
      familyName: familyName,
      authorizationCode: 'apple-auth-code',
      email: email,
      identityToken: 'apple-id-token',
      state: null,
    );

void main() {
  late RouteAdapter api;

  setUp(() {
    api = useFakeApi();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<String?> storedAccessToken() =>
      SecureStorageService().getAccessToken();

  group('Sign in with Google', () {
    testWidgets(
        'picking an account sends its ID token, keeps the tokens and goes on '
        'to the profile check', (tester) async {
      api.on('POST', '/auth/google', _tokens);
      final google = _google();
      final landed = await pumpSignIn(tester, google: google);

      await tester.tap(find.text('LOGIN WITH GOOGLE'));
      await settle(tester);

      final sent = api.sent('POST', '/auth/google').single;
      // The token is minted for the web client, whatever the phone.
      expect(sent.data, {'id_token': 'google-id-token', 'platform': 'web'});
      expect(sent.extra['skipAuth'], isTrue);
      expect(await storedAccessToken(), 'access-1');
      expect(await SecureStorageService().getRefreshToken(), 'refresh-1');
      expect(landed.single.page, 'profile-check');
      expect(landed.single.extra,
          {'accessToken': 'access-1', 'profileUrl': _photo});
      // The account is let go, so the picker asks again next time.
      verify(() => google.disconnect()).called(1);
    });

    testWidgets('closing the account picker does nothing', (tester) async {
      final landed = await pumpSignIn(tester, google: _google(cancelled: true));

      await tester.tap(find.text('LOGIN WITH GOOGLE'));
      await settle(tester);

      expect(api.requests, isEmpty);
      expect(landed, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an account without an ID token says so and sends nothing',
        (tester) async {
      final landed = await pumpSignIn(tester, google: _google(idToken: null));

      await tester.tap(find.text('LOGIN WITH GOOGLE'));
      await settle(tester);

      expect(
          find.text('Sign in failed: could not get ID token'), findsOneWidget);
      expect(api.requests, isEmpty);
      expect(landed, isEmpty);
    });

    testWidgets(
        "the picker failing (Google's error 12500, say) reads as words, not "
        'the exception', (tester) async {
      final landed = await pumpSignIn(tester,
          google: _google(
              fails: PlatformException(
                  code: 'sign_in_failed',
                  message: 'com.google.android.gms.common.api.ApiException: '
                      '12500: ')));

      await tester.tap(find.text('LOGIN WITH GOOGLE'));
      await settle(tester);

      expect(find.text('Could not sign in with Google.'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('12500'), findsNothing);
      expect(landed, isEmpty);
    });

    testWidgets(
        'a server refusing the sign-in says so, stores nothing and stays to '
        'try again', (tester) async {
      api.on('POST', '/auth/google', {'message': 'Internal Server Error'},
          status: 500);
      final landed = await pumpSignIn(tester, google: _google());

      await tester.tap(find.text('LOGIN WITH GOOGLE'));
      await settle(tester);

      expect(find.text(ApiException.serverErrorMessage), findsOneWidget);
      expect(await storedAccessToken(), isNull);
      expect(landed, isEmpty);
      expect(find.text('LOGIN WITH GOOGLE'), findsOneWidget);
    });
  });

  group('Sign in with Apple', () {
    testWidgets('not offered where Apple sign-in is not (Android)',
        (tester) async {
      await pumpSignIn(tester, apple: noApple);

      expect(find.text('LOGIN WITH APPLE'), findsNothing);
      expect(find.text('LOGIN WITH GOOGLE'), findsOneWidget);
      expect(find.text('LOGIN WITH EMAIL'), findsOneWidget);
    });

    testWidgets('offered on an iPhone, between Google and email',
        (tester) async {
      await pumpSignIn(tester, apple: _apple(credential: _appleId()));

      double top(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(find.text('LOGIN WITH APPLE'), findsOneWidget);
      expect(top('LOGIN WITH APPLE'), greaterThan(top('LOGIN WITH GOOGLE')));
      expect(top('LOGIN WITH APPLE'), lessThan(top('LOGIN WITH EMAIL')));
    });

    testWidgets(
        "Apple's credential signs in with the name Apple gives the first "
        'time, and goes on to the profile check', (tester) async {
      api.on('POST', '/auth/apple', _tokens);
      final landed =
          await pumpSignIn(tester, apple: _apple(credential: _appleId()));

      await tester.tap(find.text('LOGIN WITH APPLE'));
      await settle(tester);

      final sent = api.sent('POST', '/auth/apple').single;
      expect(sent.data, {
        'identity_token': 'apple-id-token',
        'authorization_code': 'apple-auth-code',
        'user_name': 'Asha Menon',
        'user_email': 'asha@privaterelay.appleid.com',
      });
      expect(sent.extra['skipAuth'], isTrue);
      expect(await storedAccessToken(), 'access-1');
      // Apple gives no picture.
      expect(landed.single.page, 'profile-check');
      expect(landed.single.extra, {'accessToken': 'access-1', 'profileUrl': ''});
    });

    testWidgets('a later sign-in, where Apple gives no name, sends none',
        (tester) async {
      api.on('POST', '/auth/apple', _tokens);
      await pumpSignIn(tester,
          apple: _apple(
              credential:
                  _appleId(givenName: null, familyName: null, email: null)));

      await tester.tap(find.text('LOGIN WITH APPLE'));
      await settle(tester);

      final sent = api.sent('POST', '/auth/apple').single.data as Map;
      expect(sent['user_name'], isNull);
      expect(sent['user_email'], isNull);
    });

    testWidgets("closing Apple's sheet says nothing and sends nothing",
        (tester) async {
      final landed = await pumpSignIn(tester,
          apple: _apple(
              fails: const SignInWithAppleAuthorizationException(
                  code: AuthorizationErrorCode.canceled,
                  message: 'The user canceled the authorization attempt.')));

      await tester.tap(find.text('LOGIN WITH APPLE'));
      await settle(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(api.requests, isEmpty);
      expect(landed, isEmpty);
    });

    testWidgets("Apple failing says so in words, not Apple's developer text",
        (tester) async {
      await pumpSignIn(tester,
          apple: _apple(
              fails: const SignInWithAppleAuthorizationException(
                  code: AuthorizationErrorCode.failed,
                  message: "The operation couldn't be completed. "
                      '(com.apple.AuthenticationServices.AuthorizationError '
                      'error 1000.)')));

      await tester.tap(find.text('LOGIN WITH APPLE'));
      await settle(tester);

      expect(find.text('Could not sign in with Apple. Please try again.'),
          findsOneWidget);
      expect(find.textContaining('error 1000'), findsNothing);
      expect(api.requests, isEmpty);
    });
  });
}
