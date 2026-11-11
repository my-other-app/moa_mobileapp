import 'package:finnet/app/router/link_pages.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// "Give your ticket back" (`/tickets/cancel?t=...`, the email's link):
/// Android hands it to the app, which opens the website's page for it.
void main() {
  Future<List<Uri>> pump(WidgetTester tester, String location) async {
    final opened = <Uri>[];
    final router = GoRouter(initialLocation: location, routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'tickets/cancel',
            builder: (_, state) =>
                WebsiteHandoffPage(location: state.uri.toString()),
          ),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        linkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
    return opened;
  }

  testWidgets('opens the website\'s page at once, query and all',
      (tester) async {
    final opened = await pump(tester, '/tickets/cancel?t=tok.sig');

    expect(opened, [Uri.parse('https://myotherapp.in/tickets/cancel?t=tok.sig')]);
    expect(find.text('This opens on the website'), findsOneWidget);
  });

  testWidgets('back from the browser: open it again, or go home',
      (tester) async {
    final opened = await pump(tester, '/tickets/cancel?t=tok.sig');

    await tester.tap(find.byKey(WebsiteHandoffPage.openKey));
    await tester.pump();
    expect(opened, hasLength(2));

    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
