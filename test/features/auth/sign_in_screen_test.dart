import 'dart:io';

import 'package:finnet/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real faces, so the layout is measured as a phone would draw it
/// rather than in the test font, where every glyph is a full em wide.
Future<void> _loadFonts() async {
  for (final (family, file) in [
    ('BebasNeue', 'assets/fonts/BebasNeue-Regular.ttf'),
    ('DMSans', 'assets/fonts/DMSans-VariableFont_opsz,wght.ttf'),
  ]) {
    final bytes = File(file).readAsBytesSync();
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final (name, size) in [
    ('iPhone SE', const Size(375, 667)),
    ('iPhone 16 Pro Max', const Size(440, 956)),
  ]) {
    testWidgets('on an $name the sign-in screen fits and asks for consent',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(
          child: MaterialApp(home: OnboardingInitialPage())));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final consent = find.byKey(const ValueKey('terms-consent'));
      expect(consent, findsOneWidget);
      // It comes before the buttons it is about.
      expect(tester.getTopLeft(consent).dy,
          lessThan(tester.getTopLeft(find.text('LOGIN WITH GOOGLE')).dy));
      expect(find.text('LOGIN WITH EMAIL'), findsOneWidget);
    });
  }
}
