import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_details_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the PROFILE_EXISTS code means carry on', () {
    expect(
      isProfileAlreadyExists(ApiException.fromResponse(400, {
        'message': 'A profile already exists for this account',
        'error_code': 'PROFILE_EXISTS',
      })),
      isTrue,
    );
  });

  test("an older server's words still do", () {
    expect(
      isProfileAlreadyExists(
          ApiException.fromResponse(400, {'message': 'Profile already exists'})),
      isTrue,
    );
  });

  test('any other refusal does not', () {
    expect(
      isProfileAlreadyExists(
          ApiException.fromResponse(400, {'message': 'Invalid WhatsApp number'})),
      isFalse,
    );
    expect(isProfileAlreadyExists(Exception('Profile already exists')), isFalse);
  });
}
