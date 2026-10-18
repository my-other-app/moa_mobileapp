import 'package:finnet/core/auth/jwt_claims.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/auth_fakes.dart';

void main() {
  test('reads the session id the backend puts in the token', () {
    expect(sessionIdOf(tokenWithSid('3f2c-a1')), '3f2c-a1');
  });

  test('a token from before sessions existed has none', () {
    expect(sessionIdOf(tokenWithSid(null)), isNull);
  });

  test('anything that is not a JWT has none, and does not throw', () {
    expect(sessionIdOf(null), isNull);
    expect(sessionIdOf(''), isNull);
    expect(sessionIdOf('not-a-token'), isNull);
    expect(sessionIdOf('a.%%%.c'), isNull);
  });

  test('the claims are readable', () {
    expect(unverifiedJwtClaims(tokenWithSid('s'))!['user_id'], 7);
  });
}
