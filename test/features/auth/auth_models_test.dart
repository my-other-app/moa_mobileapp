import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/data/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthTokensModel.fromJson', () {
    test('reads both tokens', () {
      final model = AuthTokensModel.fromJson(const {
        'access_token': 'at-123',
        'refresh_token': 'rt-456',
        'expires_in': 3600,
      });

      expect(model.accessToken, 'at-123');
      expect(model.refreshToken, 'rt-456');
      expect(model.expiresIn, 3600);
    });

    test('refuses a response with no access token', () {
      // This used to fall back to '', so the empty string went into secure
      // storage, the app navigated to the home screen, and every request
      // from then on sent `Authorization: Bearer ` and 401'd. The user got
      // an app that had logged them in and then refused to do anything.
      expect(
        () => AuthTokensModel.fromJson(const {'refresh_token': 'rt-456'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses a blank access token', () {
      expect(
        () => AuthTokensModel.fromJson(
          const {'access_token': '   ', 'refresh_token': 'rt'},
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses a response with no refresh token', () {
      // Without one the session cannot be renewed, so it ends at the first
      // expiry with a logout the user did not ask for.
      expect(
        () => AuthTokensModel.fromJson(const {'access_token': 'at-123'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('GoogleSignInResponse.fromJson', () {
    test('refuses a response with no access token', () {
      expect(
        () => GoogleSignInResponse.fromJson(const {'refresh_token': 'rt'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('the refusal surfaces as a failure, not a crash', () {
    test('a malformed auth response maps to ServerFailure', () {
      // It reaches the repository's catch, so a sign-in attempt comes back
      // Left -- which is the whole point: a failure, never a success holding
      // an empty credential.
      late Object thrown;
      try {
        AuthTokensModel.fromJson(const {});
      } catch (e) {
        thrown = e;
      }

      final failure = mapErrorToFailure(thrown);

      expect(failure, isA<ServerFailure>());
      expect(failure.message, contains('access_token'));
    });
  });
}
