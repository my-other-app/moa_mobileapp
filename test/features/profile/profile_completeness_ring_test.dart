import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/presentation/pages/profile_page.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import '../network/network_fixtures.dart';

class _Profiles implements ProfileRepository {
  _Profiles(this.profile);

  final UserProfile profile;

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(profile);

  @override
  Future<UserProfile?> getSavedProfile() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

UserProfile _me({Organization? organization}) => UserProfile(
      id: '7',
      fullName: 'Asha Menon',
      email: 'asha@example.com',
      organization: organization,
    );

Future<void> _pump(WidgetTester tester, UserProfile profile) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const ProfilePage()),
    GoRoute(
      path: editPublicProfileLocation,
      builder: (_, __) => const Scaffold(body: Text('public profile editor')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(_Profiles(profile))
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('the ring round the picture', () {
    testWidgets(
        'an incomplete profile: the ring, its percent, and a tap '
        'opens the public profile editor', (tester) async {
      useFakeApi().on('GET', '/me/profile', myProfileJson(score: 60));
      final handle = tester.ensureSemantics();
      await _pump(tester, _me());

      expect(find.byKey(ProfilePage.completenessRingKey), findsOneWidget);
      expect(find.byKey(ProfilePage.pictureKey), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              'Your public profile is 60% complete. Tap to finish it.'),
          findsOneWidget);
      handle.dispose();

      await tester.tap(find.byKey(ProfilePage.completenessRingKey));
      await tester.pumpAndSettle();
      expect(find.text('public profile editor'), findsOneWidget);
    });

    testWidgets('a complete profile: the picture alone, no ring',
        (tester) async {
      useFakeApi()
          .on('GET', '/me/profile', myProfileJson(score: 100, missing: []));
      await _pump(tester, _me());

      expect(find.byKey(ProfilePage.pictureKey), findsOneWidget);
      expect(find.byKey(ProfilePage.completenessRingKey), findsNothing);
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('the public profile not read: the picture alone',
        (tester) async {
      useFakeApi();
      await _pump(tester, _me());

      expect(find.byKey(ProfilePage.pictureKey), findsOneWidget);
      expect(find.byKey(ProfilePage.completenessRingKey), findsNothing);
    });
  });

  group('the name block', () {
    testWidgets('no organisation: no empty line under the name',
        (tester) async {
      useFakeApi()
          .on('GET', '/me/profile', myProfileJson(score: 100, missing: []));
      await _pump(tester, _me());

      expect(find.text('Asha Menon'), findsOneWidget);
      expect(find.text(''), findsNothing);
    });

    testWidgets('an organisation of only spaces counts as none',
        (tester) async {
      useFakeApi()
          .on('GET', '/me/profile', myProfileJson(score: 100, missing: []));
      await _pump(
          tester, _me(organization: const Organization(id: 1, name: '   ')));

      expect(find.text(''), findsNothing);
      expect(find.text('   '), findsNothing);
    });

    testWidgets('an organisation: shown under the name', (tester) async {
      useFakeApi()
          .on('GET', '/me/profile', myProfileJson(score: 100, missing: []));
      await _pump(tester,
          _me(organization: const Organization(id: 1, name: 'CET Trivandrum')));

      expect(find.text('CET Trivandrum'), findsOneWidget);
    });
  });
}
