import 'package:finnet/shared/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('NoteCard renders the design', () {
    testWidgets('the note title is the largest text, not the club name',
        (tester) async {
      // The design inverts what was there before, where the club name was
      // the heading and the note's own title sat below it -- which read as
      // a list of clubs rather than of things clubs had said.
      await tester.pumpWidget(_host(const NoteCard(
        logoUrl: '',
        headerTitle: 'Tinkerhub CET',
        headerSubtitle: '1 hour ago',
        cardTitle: 'Hack. Build. Repeat.',
        description: 'Why wait for tomorrow to start learning?',
      )));

      double sizeOf(String text) => tester
          .widget<Text>(find.text(text))
          .style!
          .fontSize!;

      expect(sizeOf('Hack. Build. Repeat.'), 22);
      expect(sizeOf('Tinkerhub CET'), 15);
      expect(sizeOf('Hack. Build. Repeat.'),
          greaterThan(sizeOf('Tinkerhub CET')));
    });

    testWidgets('club name and time sit on one line', (tester) async {
      await tester.pumpWidget(_host(const NoteCard(
        logoUrl: '',
        headerTitle: 'Tinkerhub CET',
        headerSubtitle: '1 hour ago',
        cardTitle: 'Title',
        description: 'Body',
      )));

      final club = tester.getTopLeft(find.text('Tinkerhub CET'));
      final time = tester.getTopLeft(find.text('1 hour ago'));

      expect(club.dy, time.dy);
      expect(time.dx, greaterThan(club.dx));
    });

    testWidgets('no club id means no open icon and no tap', (tester) async {
      // Rather than offering an affordance that goes nowhere.
      await tester.pumpWidget(_host(const NoteCard(
        logoUrl: '',
        headerTitle: 'Club',
        headerSubtitle: 'now',
        cardTitle: 'Title',
        description: 'Body',
      )));

      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });

    testWidgets('a club id gives an open icon', (tester) async {
      await tester.pumpWidget(_host(const NoteCard(
        logoUrl: '',
        headerTitle: 'Club',
        headerSubtitle: 'now',
        cardTitle: 'Title',
        description: 'Body',
        clubId: 5,
      )));

      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('onLinkTap overrides the icon action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_host(NoteCard(
        logoUrl: '',
        headerTitle: 'Club',
        headerSubtitle: 'now',
        cardTitle: 'Title',
        description: 'Body',
        onLinkTap: () => tapped = true,
      )));

      await tester.tap(find.byIcon(Icons.open_in_new));

      expect(tapped, isTrue);
    });

    testWidgets('an empty logo url shows the club initial, not a broken image',
        (tester) async {
      await tester.pumpWidget(_host(const NoteCard(
        logoUrl: '',
        headerTitle: 'tinkerhub',
        headerSubtitle: 'now',
        cardTitle: 'Title',
        description: 'Body',
      )));

      expect(find.text('T'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
    });

    testWidgets('a long title wraps instead of overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const NoteCard(
        logoUrl: '',
        headerTitle: 'A Club With Quite A Long Name Indeed',
        headerSubtitle: '3 weeks ago',
        cardTitle: 'The Future is Yours to Tinker, and Then Some More',
        description: 'Body text that also runs on for a good while here.',
      )));

      // No overflow exception recorded during layout.
      expect(tester.takeException(), isNull);
    });
  });
}
