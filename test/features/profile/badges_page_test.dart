import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/pages/badges/my_badges_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  testWidgets(
      "says badges are coming, under its own badge -- the picture it showed "
      'was deleted in January and every visit failed to load it',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MyBadgesPage()));
    // The image loads from the bundle; a missing one is reported then.
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('BADGES'), findsOneWidget);
    expect(find.text('BADGES DROPPING\nSOON! 🏅🔥'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/icons/mybadges.webp');
    expect(tester.takeException(), isNull);
  });

  test('is still at /profile/badges, though no longer in the Profile menu',
      () {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => _FakeAuth(
          const AuthState(accessToken: 'token', isInitialized: true))),
      routerObserversProvider.overrideWithValue(const []),
    ]);
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    expect(
        router.configuration
            .findMatch(Uri.parse('/profile/badges'))
            .last
            .route
            .name,
        AppRoutes.badges);
  });
}
