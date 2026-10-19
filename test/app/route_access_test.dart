import 'package:finnet/app/router/route_access.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which addresses need an account. The app is open without one, as the
/// website is; only what is about the person asks for sign-in.
void main() {
  group('needsAccount', () {
    const open = [
      '/',
      '/events/explore',
      '/events/explore?topic=design',
      '/events/12',
      '/events/hack-night-04',
      '/events/hack-night-04?live=room',
      '/clubs/explore',
      '/clubs/42',
      '/clubs/circuit-society',
      '/threads/7d0f3c2a-1111-4c4c-9a9a-000000000001',
      '/tickets/abc-123',
      '/certificates/abc-123',
      '/topics/development',
      // A screen a feature adds later is open unless listed.
      '/discover',
      '/threads',
    ];
    const private = [
      '/events',
      '/events/',
      '/events/registration-success',
      '/events/12/register',
      '/events/hack-night-04/register',
      '/clubs',
      '/profile',
      '/profile/edit',
      '/profile/settings',
      '/profile/notifications',
      '/profile/certificates',
      '/profile/certificates/abc-123',
      '/profile/badges',
      '/profile/interests',
      '/volunteer/events',
      '/volunteer/scanner/12',
      '/Profile/Settings',
    ];

    for (final path in open) {
      test('$path is open', () => expect(needsAccount(path), isFalse));
    }
    for (final path in private) {
      test('$path needs an account', () => expect(needsAccount(path), isTrue));
    }
  });

  test('isAuthFlow: the splash, sign-in and onboarding', () {
    expect(isAuthFlow('/splash'), isTrue);
    expect(isAuthFlow('/auth/onboarding?from=%2Fprofile'), isTrue);
    expect(isAuthFlow('/auth/verify-email'), isTrue);
    expect(isAuthFlow('/onboarding/details'), isTrue);
    expect(isAuthFlow('/'), isFalse);
    expect(isAuthFlow('/authors'), isFalse);
  });

  test('signInLocation carries the way back, query and all', () {
    final location = signInLocation('/events/12/register?x=1');
    expect(location, '/auth/onboarding?from=%2Fevents%2F12%2Fregister%3Fx%3D1');
    expect(returnTarget(Uri.parse(location)), '/events/12/register?x=1');
  });

  test('returnTarget only comes back inside the app', () {
    expect(returnTarget(Uri.parse('/auth/onboarding')), isNull);
    expect(
        returnTarget(Uri.parse(signInLocation('https://evil.example'))), isNull);
    expect(returnTarget(Uri.parse(signInLocation('//evil.example'))), isNull);
    expect(returnTarget(Uri.parse(signInLocation('/auth/onboarding'))), isNull);
    expect(returnTarget(Uri.parse(signInLocation('/'))), '/');
  });
}
