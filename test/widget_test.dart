import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/app/app.dart';
import 'package:finnet/app/router/app_router.dart';

void main() {
  testWidgets('MyApp builds a MaterialApp wired to the injected router',
      (WidgetTester tester) async {
    // routerProvider is overridden on purpose. The real one attaches
    // AnalyticsService's FirebaseAnalyticsObserver, and merely touching
    // AnalyticsService throws [core/no-app] unless Firebase.initializeApp()
    // has run — which it does in main(), but a widget test cannot do.
    // Pumping the un-overridden app therefore failed with a FirebaseException
    // rather than testing anything, which kept `flutter test` (and so the CI
    // gate) permanently red. Overriding the router keeps this a test of MyApp's
    // own wiring instead of a Firebase harness.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
