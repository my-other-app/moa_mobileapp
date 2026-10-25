import 'dart:async';

import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/presentation/pages/manual_ticket_entry_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/volunteer_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'volunteer_fakes.dart';

/// The camera, without one: the scanner starts it as on a phone, and a
/// test holds a ticket's QR up to it with [show].
class _FakeCamera extends MobileScannerPlatform {
  final _codes = StreamController<BarcodeCapture?>.broadcast();
  int starts = 0;

  void show(String? code) =>
      _codes.add(BarcodeCapture(barcodes: [Barcode(rawValue: code)]));

  @override
  Stream<BarcodeCapture?> get barcodesStream => _codes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(1280, 720),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async {}
}

const _code = 'MOA-4KD9W-22XQZ';

void main() {
  late _FakeCamera camera;
  late List<(String, Object?)> opened;

  setUp(() {
    camera = _FakeCamera();
    MobileScannerPlatform.instance = camera;
  });

  Future<void> pumpScanner(
      WidgetTester tester, FakeVolunteerRepository volunteer) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    opened = [];
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const VolunteerScannerPage(
          eventId: 7,
          eventName: 'Hack Night 04',
          clubName: 'Makers',
        ),
      ),
      GoRoute(
        path: '/volunteer/manual-entry/:eventId',
        builder: (_, state) {
          opened.add((state.uri.toString(), state.extra));
          return const Scaffold(body: Text('manual entry'));
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [volunteerRepositoryProvider.overrideWithValue(volunteer)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  /// Hold [code] up to the camera and let the answer arrive.
  Future<void> scan(WidgetTester tester, String? code) async {
    camera.show(code);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('the scanner', () {
    testWidgets('starts the camera, under the event\'s name', (tester) async {
      await pumpScanner(tester, FakeVolunteerRepository());

      expect(camera.starts, 1);
      expect(find.text('HACK NIGHT 04'), findsOneWidget);
      expect(find.text('SCAN QR CODE'), findsOneWidget);
    });

    testWidgets(
        'a good ticket: checked, not admitted -- the holder, then GRANT ENTRY '
        'checks them in', (tester) async {
      final volunteer = FakeVolunteerRepository();
      await pumpScanner(tester, volunteer);

      await scan(tester, _code);

      expect(volunteer.calls, ['validate(7,$_code)']);
      expect(find.text('AARAV MENON'), findsOneWidget);
      expect(find.text('aarav@example.com'), findsOneWidget);
      expect(find.text('11/10/2026'), findsOneWidget);
      expect(find.text('19:30'), findsOneWidget);
      expect(find.text(_code), findsOneWidget);
      // The event, in the header and on the result.
      expect(find.text('HACK NIGHT 04'), findsNWidgets(2));

      await tester.tap(find.text('GRANT ENTRY'));
      await tester.pump();
      await tester.pump();

      expect(volunteer.calls, ['validate(7,$_code)', 'checkin(7,$_code)']);
      expect(find.text('Entry granted successfully!'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('AARAV MENON'), findsNothing);
    });

    testWidgets('while a result is up, the camera seeing more asks nothing',
        (tester) async {
      final volunteer = FakeVolunteerRepository();
      await pumpScanner(tester, volunteer);

      await scan(tester, _code);
      await scan(tester, 'MOA-OTHER-TICKT');
      await scan(tester, _code);

      expect(volunteer.calls, ['validate(7,$_code)']);
    });

    testWidgets('an empty code is not a scan', (tester) async {
      final volunteer = FakeVolunteerRepository();
      await pumpScanner(tester, volunteer);

      await scan(tester, '');
      await scan(tester, null);

      expect(volunteer.calls, isEmpty);
      expect(find.text('GRANT ENTRY'), findsNothing);
    });

    testWidgets('SCAN ANOTHER closes the result, and the next code is read',
        (tester) async {
      final volunteer = FakeVolunteerRepository(
        validation: const CheckinResult.refused(
          type: CheckinResultType.notFound,
          message: 'Ticket not found',
        ),
      );
      await pumpScanner(tester, volunteer);

      await scan(tester, 'MOA-NOPE0-NOPE0');
      expect(find.text('TICKET NOT FOUND'), findsOneWidget);
      expect(find.text('GRANT ENTRY'), findsNothing);

      await tester.tap(find.text('SCAN ANOTHER'));
      await tester.pumpAndSettle();
      expect(find.text('TICKET NOT FOUND'), findsNothing);

      volunteer.validation = validTicket;
      await scan(tester, _code);
      expect(volunteer.calls,
          ['validate(7,MOA-NOPE0-NOPE0)', 'validate(7,$_code)']);
      expect(find.text('GRANT ENTRY'), findsOneWidget);
    });

    for (final (type, message, shown) in [
      (
        CheckinResultType.alreadyScanned,
        'User already checked-in',
        'THIS TICKET HAS ALREADY BEEN SCANNED'
      ),
      (CheckinResultType.unpaid, 'Payment pending', 'PAYMENT REQUIRED'),
      (
        CheckinResultType.incorrectEvent,
        'This ticket is for another event: Design Jam',
        'INCORRECT EVENT'
      ),
      (
        CheckinResultType.notPermitted,
        'You are not a volunteer for this event',
        'NOT YOUR EVENT'
      ),
      (
        CheckinResultType.unreachable,
        'No answer from the server. Scan it again.',
        'NO ANSWER'
      ),
    ]) {
      testWidgets('a refusal ($type) says why, and admits no one',
          (tester) async {
        final volunteer = FakeVolunteerRepository(
          validation: CheckinResult.refused(type: type, message: message),
        );
        await pumpScanner(tester, volunteer);

        await scan(tester, _code);

        expect(find.text(shown), findsOneWidget);
        expect(find.text('GRANT ENTRY'), findsNothing);
        expect(find.text('SCAN ANOTHER'), findsOneWidget);
        expect(volunteer.calls, ['validate(7,$_code)']);
        if (type == CheckinResultType.incorrectEvent) {
          // The event it is really for.
          expect(find.text('Design Jam'), findsOneWidget);
        }
        if (type == CheckinResultType.notPermitted ||
            type == CheckinResultType.unreachable) {
          expect(find.text(message), findsOneWidget);
        }
      });
    }

    testWidgets('a check-in refused at GRANT ENTRY says so', (tester) async {
      final volunteer = FakeVolunteerRepository(
        checkinResult: const CheckinResult.refused(
          type: CheckinResultType.alreadyScanned,
          message: 'User already checked-in',
        ),
      );
      await pumpScanner(tester, volunteer);

      await scan(tester, _code);
      await tester.tap(find.text('GRANT ENTRY'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Failed to check in: User already checked-in'),
          findsOneWidget);
      expect(find.text('Entry granted successfully!'), findsNothing);
    });

    testWidgets('ENTER TICKET CODE MANUALLY opens the code page for the event',
        (tester) async {
      await pumpScanner(tester, FakeVolunteerRepository());

      await tester.tap(find.text('ENTER TICKET CODE MANUALLY'));
      await tester.pumpAndSettle();

      expect(find.text('manual entry'), findsOneWidget);
      expect(opened.single.$1, '/volunteer/manual-entry/7');
      expect(opened.single.$2,
          {'eventName': 'Hack Night 04', 'clubName': 'Makers'});
    });
  });

  group('checking in by ticket code', () {
    Future<void> pumpManual(
        WidgetTester tester, FakeVolunteerRepository volunteer) async {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [volunteerRepositoryProvider.overrideWithValue(volunteer)],
        child: const MaterialApp(
          home: ManualTicketEntryPage(
            eventId: 7,
            eventName: 'Hack Night 04',
            clubName: 'Makers',
          ),
        ),
      ));
    }

    testWidgets('nothing typed: asks for the code, and sends nothing',
        (tester) async {
      final volunteer = FakeVolunteerRepository();
      await pumpManual(tester, volunteer);

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(find.text('Enter the ticket code'), findsOneWidget);
      expect(volunteer.calls, isEmpty);
    });

    testWidgets('a code checks the holder in, and the field is ready again',
        (tester) async {
      final volunteer = FakeVolunteerRepository();
      await pumpManual(tester, volunteer);

      await tester.enterText(find.byType(TextFormField), '  $_code ');
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      await tester.pump();

      expect(volunteer.calls, ['checkin(7,$_code)']);
      expect(find.text('Check-in successful!'), findsOneWidget);
      expect(
          tester.widget<TextFormField>(find.byType(TextFormField)).controller!
              .text,
          isEmpty);
    });

    testWidgets(
        'a refusal stays under the field until the code is changed',
        (tester) async {
      final volunteer = FakeVolunteerRepository(
        checkinResult: const CheckinResult.refused(
          type: CheckinResultType.notFound,
          message: 'No ticket with this code. Check the Ticket ID.',
        ),
      );
      await pumpManual(tester, volunteer);

      await tester.enterText(find.byType(TextFormField), 'MOA-0042-E12');
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No ticket with this code. Check the Ticket ID.'),
          findsOneWidget);
      expect(find.text('Check-in successful!'), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'MOA-4KD9W');
      await tester.pump();
      expect(find.text('No ticket with this code. Check the Ticket ID.'),
          findsNothing);
    });
  });
}
