import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/auth/data/services/profile_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/cubits/profile_cubit.dart';
import 'package:finnet/features/auth/presentation/sign_in_errors.dart';
import 'package:flutter_test/flutter_test.dart';

class _Answer implements HttpClientAdapter {
  _Answer(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

Future<ProfileFailure> _failureFor(int status, String body) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _Answer(status, body)
    ..interceptors.add(ErrorInterceptor());
  final cubit = ProfileCubit(profileService: ProfileService(dio: dio));
  await cubit.getProfile('token');
  return cubit.state as ProfileFailure;
}

void main() {
  test('a club account at the profile check is told what it is', () async {
    // /user/profile/me takes attendee accounts only. This used to show
    // "Profile error: Not Authorized" over a spinner that never stopped.
    final failure = await _failureFor(403,
        '{"message":"Not Authorized","error_code":"INSUFFICIENT_PERMISSIONS"}');

    expect(failure.error, clubAccountMessage);
    expect(failure.needsSignIn, isTrue);
  });

  test('an ended session sends the person back to sign in', () async {
    final failure =
        await _failureFor(401, '{"message":"Could not validate credentials"}');

    expect(failure.needsSignIn, isTrue);
  });

  test('a server error can be tried again, and says so plainly', () async {
    final failure =
        await _failureFor(500, '{"message":"Internal Server Error"}');

    expect(failure.needsSignIn, isFalse);
    expect(failure.error, isNot(contains('Internal Server Error')));
    expect(failure.error, isNot(contains('Exception')));
  });

  test('push registration never throws, even without Firebase', () async {
    // NotificationService's constructor throws when Firebase is not set up,
    // as in a test or after a failed start-up. Signing out must not.
    const push = NotificationPushRegistration();

    await expectLater(push.onSignedOut(), completes);
    await expectLater(push.onSignedIn(), completes);
  });
}
