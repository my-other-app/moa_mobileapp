import 'package:dio/dio.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/auth/data/services/authentication_service.dart';
import 'package:finnet/features/auth/data/services/profile_service.dart';
import 'package:finnet/features/auth/presentation/cubits/login_cubit.dart';
import 'package:finnet/features/auth/presentation/sign_in_errors.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';

/// What APIService.request throws for a refused call: the ApiException.
ApiException _refused(int status, Map<String, dynamic> body) =>
    ApiException.fromResponse(status, body);

class _FakeAuthService implements AuthenticationService {
  Object? signInThrows;
  Map<String, dynamic> tokens = {
    'access_token': 'access',
    'refresh_token': 'refresh',
    'token_type': 'Bearer',
  };

  /// What `/auth/me` answers: a user_type, or an error to throw.
  Object accountType = 'app_user';
  final List<String> accountChecks = [];

  Future<Map<String, dynamic>> _answer() async {
    final error = signInThrows;
    if (error != null) throw error;
    return tokens;
  }

  /// The authenticator codes sent with each email sign-in.
  final List<String?> totpCodes = [];

  /// When set, a sign-in without this exact code is refused as the server
  /// refuses an account with two-step verification on.
  String? requiresTotp;

  @override
  Future<Map<String, dynamic>> signInWithEmail(
      {required String email, required String password, String? totpCode}) {
    totpCodes.add(totpCode);
    final needed = requiresTotp;
    if (needed != null && totpCode != needed) {
      throw totpCode == null
          ? _refused(401, {
              'message': 'Enter the code from your authenticator app',
              'error_code': 'TOTP_REQUIRED',
            })
          : _refused(401, {
              'message': 'That code is not valid',
              'error_code': 'TOTP_INVALID',
            });
    }
    return _answer();
  }

  @override
  Future<Map<String, dynamic>> signUpWithEmail(
          {required String fullName,
          required String email,
          required String password}) =>
      _answer();

  @override
  Future<Map<String, dynamic>> signInWithGoogle(
          {required String idToken, required String platform}) =>
      _answer();

  @override
  Future<Map<String, dynamic>> signInWithApple(
          {required String identityToken,
          required String authorizationCode,
          String? userName,
          String? userEmail}) =>
      _answer();

  @override
  Future<String?> accountTypeOf(String accessToken) async {
    accountChecks.add(accessToken);
    final answer = accountType;
    if (answer is String) return answer;
    throw answer;
  }
}

void main() {
  late _FakeAuthService auth;
  late MemoryStorage storage;
  late FakeSessionRevoker revoker;
  late LoginCubit cubit;
  late List<LoginState> states;

  setUp(() {
    auth = _FakeAuthService();
    storage = MemoryStorage();
    revoker = FakeSessionRevoker();
    cubit = LoginCubit(
      authService: auth,
      profileService: ProfileService(dio: Dio()),
      secureStorage: storage,
      sessionRevoker: revoker,
    );
    states = [];
    cubit.onStateChanged = states.add;
  });

  String failureOf(List<LoginState> states) =>
      (states.last as LoginFailure).error;

  group('a failed sign-in reads as words, never as the exception', () {
    test('a wrong password', () async {
      auth.signInThrows =
          _refused(401, {'message': 'Incorrect username or password'});

      await cubit.loginWithEmail('a@b.c', 'nope');

      // It used to read "ApiException: Unauthorized. Please log in again.
      // (unauthorized, code: 401)", then the server's "Incorrect username or
      // password"; now it says what to do about it.
      expect(failureOf(states), wrongPasswordMessage);
    });

    test('too many wrong passwords: the server says how long to wait',
        () async {
      auth.signInThrows = _refused(429, {
        'message': 'Too many wrong passwords. Try again in 5 min.',
        'error_code': 'LOGIN_LOCKED',
      });

      await cubit.loginWithEmail('a@b.c', 'nope');

      expect(
          failureOf(states), 'Too many wrong passwords. Try again in 5 min.');
    });

    test('a suspended account', () async {
      auth.signInThrows = _refused(403, {
        'message': 'This account has been suspended',
        'error_code': 'ACCOUNT_SUSPENDED',
      });

      await cubit.loginWithEmail('a@b.c', 'pw');

      expect(failureOf(states), ApiException.accountSuspendedMessage);
    });

    test('a club waiting for approval', () async {
      auth.signInThrows = _refused(403, {
        'message': 'Your club is waiting for approval.',
        'error_code': 'CLUB_NOT_VERIFIED',
      });

      await cubit.loginWithEmail('a@b.c', 'pw');

      expect(failureOf(states), clubAccountMessage);
    });

    test('a server error, from Google', () async {
      auth.signInThrows = _refused(500, {'message': 'Internal Server Error'});

      await cubit.loginWithGoogle('id-token', 'web', '');

      expect(failureOf(states), ApiException.serverErrorMessage);
    });

    test('anything unexpected', () async {
      auth.signInThrows = StateError('Bad state: no element');

      await cubit.loginWithApple('id', 'code', null, null);

      expect(failureOf(states), signInFailedMessage);
    });

    test('an answer without tokens is a failure, not a success', () async {
      auth.tokens = {'token_type': 'Bearer'};

      await cubit.loginWithGoogle('id-token', 'web', '');

      expect(failureOf(states), signInFailedMessage);
      expect(storage.values, isEmpty);
    });
  });

  group('a club account signing in with email', () {
    test('is refused, its session ended, and nothing stored', () async {
      auth.accountType = 'club';

      await cubit.loginWithEmail('club@b.c', 'pw');

      expect(failureOf(states), clubAccountMessage);
      expect(revoker.revoked, ['access']);
      // Not the app's stored session: its token is sent by hand.
      expect(revoker.stored, [false]);
      expect(storage.values, isEmpty);
    });

    test('is refused when the server says the club is unverified', () async {
      auth.accountType = _refused(403, {
        'message': 'Club is not verified',
        'error_code': 'CLUB_NOT_VERIFIED'
      });

      await cubit.loginWithEmail('club@b.c', 'pw');

      expect(failureOf(states), clubAccountMessage);
      expect(storage.values, isEmpty);
    });

    test('an attendee goes through', () async {
      await cubit.loginWithEmail('me@b.c', 'pw');

      expect(states.last, isA<LoginSuccess>());
      expect(auth.accountChecks, ['access']);
      expect(storage.values['access_token'], 'access');
      expect(revoker.revoked, isEmpty);
    });

    test('a check that cannot be made does not lock an attendee out', () async {
      auth.accountType = const ApiException(
        message: ApiException.networkMessage,
        type: ApiExceptionType.network,
      );

      await cubit.loginWithEmail('me@b.c', 'pw');

      expect(states.last, isA<LoginSuccess>());
    });
  });

  test('Google sign-in is not checked: it only signs in attendees', () async {
    await cubit.loginWithGoogle('id-token', 'web', 'https://photo');

    expect(states.last, isA<LoginSuccess>());
    expect(auth.accountChecks, isEmpty);
  });

  group('two-step verification', () {
    test('the right password asks for the code, and nothing is stored',
        () async {
      auth.requiresTotp = '123456';

      await cubit.loginWithEmail('a@b.c', 'pw');

      final asked = states.last as LoginNeedsTwoStep;
      expect(asked.email, 'a@b.c');
      expect(asked.password, 'pw');
      expect(asked.error, isNull);
      expect(storage.values, isEmpty);
    });

    test('the code goes with the same email and password, and signs in',
        () async {
      auth.requiresTotp = '123456';
      await cubit.loginWithEmail('a@b.c', 'pw');

      await cubit.loginWithEmail('a@b.c', 'pw', totpCode: '123456');

      expect(auth.totpCodes, [null, '123456']);
      expect(states.last, isA<LoginSuccess>());
      expect(storage.values['access_token'], 'access');
    });

    test('a wrong code asks again, saying so', () async {
      auth.requiresTotp = '123456';

      await cubit.loginWithEmail('a@b.c', 'pw', totpCode: '000000');

      final asked = states.last as LoginNeedsTwoStep;
      expect(asked.error, twoStepWrongCodeMessage);
      expect(storage.values, isEmpty);
    });

    test('a recovery code is sent as the code', () async {
      auth.requiresTotp = 'ab12-cd34-ef56-7890';

      await cubit.loginWithEmail('a@b.c', 'pw',
          totpCode: 'ab12-cd34-ef56-7890');

      expect(states.last, isA<LoginSuccess>());
    });
  });
}
