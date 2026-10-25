import 'dart:convert';
import 'dart:io';

import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

const _share = MethodChannel('dev.fluttercommunity.plus/share');
const _calendar = MethodChannel('add_2_calendar');
const _browser = MethodChannel('plugins.flutter.io/url_launcher');
const _passKit = MethodChannel('apple_passkit');

/// The ticket's PDF, as [DocumentCache] hands it back -- without the disk,
/// which a widget test's fake clock never lets answer.
class _Pdfs extends DocumentCache {
  _Pdfs(this.answer);

  /// What a fetch gives back (or throws).
  SavedDocument Function() answer;
  final fetched = <(String, String)>[];

  @override
  Future<SavedDocument> fetch(
    String path, {
    required String name,
    String? version,
    Map<String, dynamic>? extra,
  }) async {
    fetched.add((path, name));
    return answer();
  }
}

SavedDocument _kept({bool current = true}) => SavedDocument(
      file: File('/kept/documents/ticket_T-1.pdf'),
      current: current,
    );

/// Records the calls on [channel], answering each with [answer].
List<MethodCall> _record(
  WidgetTester tester,
  MethodChannel channel, [
  Object? Function(MethodCall call)? answer,
]) {
  final calls = <MethodCall>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    return answer?.call(call);
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

final _startsAt = DateTime.utc(2030, 12, 1, 10);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpTicket(WidgetTester tester, {DateTime? startsAt}) async {
  tester.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: TicketViewPage(
      ticketId: 'T-1',
      eventName: 'Hack Night',
      eventDateTime: startsAt,
      locationName: 'CET',
      durationHours: 2.5,
    ),
  ));
  // The glow animates forever: pump, don't settle.
  await _settle(tester);
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await _settle(tester);
}

void main() {
  late _Pdfs pdfs;

  setUp(() {
    useFakeApi();
    pdfs = _Pdfs(_kept);
    DocumentCache.instance = pdfs;
  });
  tearDown(() {
    DocumentCache.instance = null;
    debugDefaultTargetPlatformOverride = null;
  });

  group('Download', () {
    testWidgets(
        "saves the ticket's PDF and offers to open it", (tester) async {
      await _pumpTicket(tester);
      await _tapAction(tester, 'Download');

      expect(pdfs.fetched, [('/events/tickets/T-1/pdf', 'ticket_T-1.pdf')]);
      expect(find.text('Ticket saved!'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Open'), findsOneWidget);
      // Ready for another tap.
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('offline, the copy kept on the phone, and it says so',
        (tester) async {
      pdfs.answer = () => _kept(current: false);
      await _pumpTicket(tester);
      await _tapAction(tester, 'Download');

      expect(find.text('Offline — this is your saved copy'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Open'), findsOneWidget);
    });

    testWidgets('a PDF that cannot be had says the download failed',
        (tester) async {
      pdfs.answer = () => throw const SocketException('offline');
      await _pumpTicket(tester);
      await _tapAction(tester, 'Download');

      expect(find.text('Download failed'), findsOneWidget);
      expect(find.text('Ticket saved!'), findsNothing);
    });
  });

  group('Share', () {
    testWidgets('shares the PDF itself, with a line about the event',
        (tester) async {
      final shared = _record(tester, _share, (_) => 'shared');
      await _pumpTicket(tester, startsAt: _startsAt);

      await tester.tap(find.byIcon(Icons.share_outlined));
      await _settle(tester);

      expect(pdfs.fetched.single.$1, '/events/tickets/T-1/pdf');
      final call = shared.single;
      expect(call.method, 'shareFiles');
      final args = call.arguments as Map;
      expect(args['paths'], ['/kept/documents/ticket_T-1.pdf']);
      expect(args['mimeTypes'], ['application/pdf']);
      expect(args['text'], '🎟️ Here is my ticket for Hack Night!');
    });

    testWidgets(
        'without the PDF, says so and shares the link to the ticket instead',
        (tester) async {
      pdfs.answer = () => throw const SocketException('offline');
      final shared = _record(tester, _share, (_) => 'shared');
      await _pumpTicket(tester, startsAt: _startsAt);

      await tester.tap(find.byIcon(Icons.share_outlined));
      await _settle(tester);

      expect(
          find.text("Couldn't share the PDF, so here's the link to your "
              'ticket.'),
          findsOneWidget);
      final call = shared.single;
      expect(call.method, 'share');
      final text = (call.arguments as Map)['text'] as String;
      expect(text, contains('Hack Night'));
      expect(text, contains('CET'));
      expect(text, contains('https://myotherapp.in/tickets/T-1'));
    });
  });

  group('Calendar', () {
    testWidgets(
        "adds the event to the phone's calendar, with the ticket in the notes",
        (tester) async {
      final added = _record(tester, _calendar, (_) => true);
      await _pumpTicket(tester, startsAt: _startsAt);
      await _tapAction(tester, 'Calendar');

      final args = added.single.arguments as Map;
      expect(added.single.method, 'add2Cal');
      expect(args['title'], 'Hack Night');
      expect(args['location'], 'CET');
      expect(args['startDate'], _startsAt.millisecondsSinceEpoch);
      // Two and a half hours.
      expect(args['endDate'],
          _startsAt.add(const Duration(minutes: 150)).millisecondsSinceEpoch);
      expect(args['desc'], 'Ticket: T-1\nhttps://myotherapp.in/tickets/T-1');
      expect(find.text("Couldn't open your calendar"), findsNothing);
    });

    testWidgets(
        'no calendar app: Google Calendar in the browser, with the event',
        (tester) async {
      _record(tester, _calendar, (_) => false);
      final opened = _record(tester, _browser, (_) => true);
      await _pumpTicket(tester, startsAt: _startsAt);
      await _tapAction(tester, 'Calendar');

      final url = Uri.parse((opened.single.arguments as Map)['url'] as String);
      expect(url.host, 'calendar.google.com');
      expect(url.queryParameters['text'], 'Hack Night');
      expect(url.queryParameters['location'], 'CET');
      expect(find.text("Couldn't open your calendar"), findsNothing);
    });

    testWidgets('neither: says the calendar could not open', (tester) async {
      _record(tester, _calendar, (_) => false);
      _record(tester, _browser, (_) => false);
      await _pumpTicket(tester, startsAt: _startsAt);
      await _tapAction(tester, 'Calendar');

      expect(find.text("Couldn't open your calendar"), findsOneWidget);
    });

    testWidgets('a ticket without a date has nothing to add, and says so',
        (tester) async {
      final added = _record(tester, _calendar, (_) => true);
      await _pumpTicket(tester);
      await _tapAction(tester, 'Calendar');

      expect(added, isEmpty);
      expect(find.text('Event date not available'), findsOneWidget);
    });
  });

  group('Add to Wallet (iPhone)', () {
    testWidgets(
        'downloads the pass from /events/tickets/T-1/wallet.pkpass and hands '
        'it to Wallet', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final api = useFakeApi()
        ..on('GET', '/events/tickets/T-1/wallet.pkpass', 'PKPASS');
      final passKit = _record(tester, _passKit,
          (call) => call.method == 'isPassLibraryAvailable' ? true : null);
      await _pumpTicket(tester);
      await _tapAction(tester, 'Add to Wallet');

      expect(api.sent('GET', '/events/tickets/T-1/wallet.pkpass'),
          hasLength(1));
      expect(passKit.map((c) => c.method),
          ['isPassLibraryAvailable', 'addPassViewController']);
      final pass = (passKit.last.arguments as List).single as Uint8List;
      expect(pass, utf8.encode(jsonEncode('PKPASS')));
      expect(find.text('Pass added to Apple Wallet!'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets("a phone without Wallet's library gets the explanation",
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      useFakeApi().on('GET', '/events/tickets/T-1/wallet.pkpass', 'PKPASS');
      final passKit = _record(tester, _passKit, (_) => false);
      await _pumpTicket(tester);
      await _tapAction(tester, 'Add to Wallet');

      expect(passKit.map((c) => c.method), ['isPassLibraryAvailable']);
      expect(find.text('Wallet Pass Coming Soon'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        "a pass the server won't give says it couldn't be added, and adds "
        'nothing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // The pass is fetched as bytes, so a refusal's JSON isn't read: the
      // page says so in its own words, never an exception's.
      useFakeApi().on('GET', '/events/tickets/T-1/wallet.pkpass',
          {'message': 'Wallet passes are not set up for this event'},
          status: 404);
      final passKit = _record(tester, _passKit, (_) => true);
      await _pumpTicket(tester);
      await _tapAction(tester, 'Add to Wallet');

      expect(passKit, isEmpty);
      expect(
          find.text("We couldn't add this ticket to Apple Wallet. "
              'Try again in a moment.'),
          findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('Add to Wallet'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
