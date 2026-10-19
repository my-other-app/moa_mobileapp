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
      // Open, each asking for an account at its own action.
      '/events/12/register',
      '/events/hack-night-04/register',
      '/events/hack-night-04/compete',
      '/feedback/12/34',
      // Batch C's pages.
      '/following/posts',
      '/verify/certificates',
      '/verify/certificates/certificate:abc-123',
      '/auth/forgot-password',
      // Batch A's pages; and any screen a feature adds is open unless listed.
      '/discover/events',
      '/discover/clubs',
      '/discover/threads',
      '/topics',
      '/threads',
    ];
    const private = [
      '/events',
      '/events/',
      '/events/registration-success',
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

  test('profileCheckLocation passes a safe way back on', () {
    expect(profileCheckLocation('/events/12'),
        '/auth/profile-check?from=%2Fevents%2F12');
    expect(profileCheckLocation(null), '/auth/profile-check');
    expect(profileCheckLocation('https://evil.example'), '/auth/profile-check');
    expect(safeReturnPath('/\\evil.example'), isNull);
    expect(safeReturnPath('/events/12?x=1'), '/events/12?x=1');
  });

  test('returnTarget only comes back inside the app', () {
    expect(returnTarget(Uri.parse('/auth/onboarding')), isNull);
    expect(returnTarget(Uri.parse(signInLocation('https://evil.example'))),
        isNull);
    expect(returnTarget(Uri.parse(signInLocation('//evil.example'))), isNull);
    expect(returnTarget(Uri.parse(signInLocation('/auth/onboarding'))), isNull);
    expect(returnTarget(Uri.parse(signInLocation('/'))), '/');
  });
}
