import 'package:finnet/features/auth/presentation/widgets/terms_consent.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Uri>> _pump(WidgetTester tester, {bool launches = true}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      linkLauncherProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return launches;
      }),
    ],
    child: const MaterialApp(
      home: Scaffold(body: Center(child: TermsConsent())),
    ),
  ));
  return opened;
}

void main() {
  testWidgets('says what continuing agrees to', (tester) async {
    await _pump(tester);

    expect(
      find.text('By continuing, you agree to our Terms and Privacy Policy.',
          findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Terms opens the terms on the website', (tester) async {
    final opened = await _pump(tester);

    await tester.tapOnText(find.textRange.ofSubstring('Terms'));
    await tester.pump();

    expect(opened, [Uri.parse('https://myotherapp.in/terms')]);
  });

  testWidgets('Privacy Policy opens the policy on the website',
      (tester) async {
    final opened = await _pump(tester);

    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    await tester.pump();

    expect(opened, [Uri.parse('https://myotherapp.in/privacy')]);
  });

  testWidgets('a link that cannot open says so', (tester) async {
    await _pump(tester, launches: false);

    await tester.tapOnText(find.textRange.ofSubstring('Terms'));
    await tester.pump();

    expect(find.textContaining("Couldn't open"), findsOneWidget);
  });
}
