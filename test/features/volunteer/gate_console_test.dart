import 'dart:async';

import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';
import 'package:finnet/features/volunteer/presentation/pages/manual_ticket_entry_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/volunteer_scanner_page.dart';
import 'package:finnet/features/volunteer/presentation/providers/gate_controller.dart';
import 'package:finnet/features/volunteer/presentation/widgets/gate_outcome_card.dart';
import 'package:finnet/features/volunteer/presentation/widgets/gate_sync_panel.dart';
import 'package:finnet/features/volunteer/presentation/widgets/guest_search.dart';
import 'package:finnet/features/volunteer/presentation/widgets/merch_handover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'volunteer_fakes.dart';

/// The camera, without one: the console starts it as on a phone, and a
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
  late FakeGateApi api;
  late MemoryScanQueueStore queue;
  late NetworkStatus network;

  setUp(() {
    camera = _FakeCamera();
    MobileScannerPlatform.instance = camera;
    api = FakeGateApi(context: gateContext(door: 'Main gate'));
    queue = MemoryScanQueueStore();
    network = NetworkStatus(probe: () async => false);
  });

  tearDown(() => network.dispose());

  Future<void> pump(WidgetTester tester, {String eventName = 'Hack Night'}) async {
    tester.view
      ..physicalSize = const Size(900, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/door'),
            child: const Text('open door'),
          ),
        ),
      ),
      GoRoute(
        path: '/door',
        builder: (_, __) => VolunteerScannerPage(
            eventId: 7, eventName: eventName, clubName: 'Makers'),
      ),
      GoRoute(
        path: '/volunteer/manual-entry/:eventId',
        builder: (_, state) => ManualTicketEntryPage(
            eventId: int.parse(state.pathParameters['eventId']!),
            eventName: 'Hack Night',
            clubName: 'Makers'),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gateApiProvider.overrideWithValue(api),
        scanQueueStoreProvider.overrideWithValue(queue),
        gateDrainEveryProvider.overrideWithValue(null),
        networkStatusProvider.overrideWithValue(network),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.tap(find.text('open door'));
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, String code) async {
    camera.show(code);
    await tester.pump();
    await tester.pump();
  }

  group('the door', () {
    testWidgets(
        "opens on the event, its count and this volunteer's door, camera on",
        (tester) async {
      await pump(tester, eventName: 'Event');

      expect(find.text('HACK NIGHT 04'), findsOneWidget);
      expect(find.text('10 of 120 in · Main gate'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Find'), findsOneWidget);
      // No merch switch: no Merch tab.
      expect(find.text('Merch'), findsNothing);
      expect(camera.starts, 1);
    });

    testWidgets('a QR checks its holder in at once, and says so',
        (tester) async {
      api.scanAnswers.add(scanned(ScanOutcome.checkedIn, who: guest()));
      await pump(tester);

      await show(tester, _code);

      expect(api.scans.single.code, _code);
      expect(api.scans.single.door, 'Main gate');
      expect(find.text('Aarav Menon — welcome in.'), findsOneWidget);
      expect(find.text('11 of 120 in · Main gate'), findsOneWidget);

      // The same ticket still in front of the camera is not a second scan.
      await show(tester, _code);
      expect(api.scans, hasLength(1));

      // An admission clears itself, so it never blocks the next scan.
      await tester.pump(VolunteerScannerPage.admitCardFor);
      await tester.pump();
      expect(find.text('Aarav Menon — welcome in.'), findsNothing);
    });

    testWidgets('a refusal says why, and stays until closed', (tester) async {
      api.scanAnswers
          .add(scanned(ScanOutcome.wrongEvent, otherEvent: 'Robotics Day'));
      await pump(tester);

      await show(tester, _code);
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('That ticket is for another event.'), findsOneWidget);
      expect(find.text('VALID TICKET · ROBOTICS DAY'), findsOneWidget);
      await tester.tap(find.byKey(GateOutcomeCard.closeKey));
      await tester.pump();
      expect(find.text('That ticket is for another event.'), findsNothing);
    });

    testWidgets('an admission number offers to check its holder in by hand',
        (tester) async {
      api.scanAnswers.add(scanned(ScanOutcome.invalid,
          who: guest(id: 'reg-5', admissionNo: 'MOA-0042-E7'),
          hint: admissionNumberHint));
      await pump(tester);

      await show(tester, 'MOA-0042-E7');
      await tester.tap(find.byKey(GateOutcomeCard.byHandKey));
      await tester.pumpAndSettle();

      expect(api.byHand.single, ('reg-5', 'Main gate'));
      expect(find.text('Aarav Menon — welcome in.'), findsOneWidget);
    });
  });

  group('no signal at the door', () {
    testWidgets(
        'the scan is saved and says so; Send now sends it; all checked in',
        (tester) async {
      api.scanAnswers.add(noSignal('/scan'));
      await pump(tester);

      await show(tester, _code);

      expect(find.text('No signal — saved on this phone.'), findsOneWidget);
      expect(find.textContaining('1 scan saved on this phone'), findsOneWidget);
      expect(await queue.all(7), hasLength(1));

      await tester.tap(find.byKey(GateSyncPanel.sendNowKey));
      await tester.pumpAndSettle();

      expect(api.batches.single.single.code, _code);
      expect(find.text('1 saved scan sent, all checked in.'), findsOneWidget);
      expect(find.textContaining('saved on this phone, waiting'), findsNothing);
      await tester.tap(find.byKey(GateSyncPanel.doneKey));
      await tester.pump();
      expect(find.text('1 saved scan sent, all checked in.'), findsNothing);
    });

    testWidgets(
        'the saved scans the server then refused are listed by name, with why',
        (tester) async {
      api.scanAnswers.add(noSignal('/scan'));
      api.batchAnswer = (s) => s.code == 'MOA-BBBBB-BBBBB'
          ? scanned(ScanOutcome.revoked,
              who: guest(name: 'Diya Nair', ticket: 'MOA-BBBBB-BBBBB'))
          : scanned(ScanOutcome.checkedIn, who: guest());
      await pump(tester);

      await show(tester, 'MOA-AAAAA-AAAAA');
      await tester.pump(const Duration(seconds: 8));
      await show(tester, 'MOA-BBBBB-BBBBB');
      expect(find.textContaining('2 scans saved on this phone'), findsOneWidget);

      // The signal comes back.
      network.reportOffline();
      network.reportOnline();
      await tester.pumpAndSettle();

      expect(find.text('1 saved scan needs a look'), findsOneWidget);
      expect(find.textContaining('Checked in: 1 of 2 sent.'), findsOneWidget);
      expect(find.text('Diya Nair'), findsOneWidget);
      expect(find.text('Revoked'), findsOneWidget);
      expect(find.textContaining('cancelled or refunded'), findsOneWidget);
    });

    testWidgets('the console opens without signal and still saves scans',
        (tester) async {
      api.context_ = noSignal('/context');
      api.scanAnswers.add(noSignal('/scan'));
      await pump(tester, eventName: 'Hack Night');

      expect(find.text('HACK NIGHT'), findsOneWidget);
      expect(find.textContaining('Scans are still saved and sent later.'),
          findsOneWidget);
      await show(tester, _code);
      expect(await queue.all(7), hasLength(1));
    });
  });

  group('find a guest by name', () {
    testWidgets('and check them in by hand', (tester) async {
      api.found = [guest(id: 'reg-3', name: 'Diya Nair')];
      await pump(tester);

      await tester.tap(find.text('Find'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GuestSearch.fieldKey), 'diya');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(api.searches, ['diya']);
      expect(find.text('Not checked in'), findsOneWidget);
      await tester.tap(find.byKey(GuestSearch.rowKey('reg-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VolunteerScannerPage.guestCheckInKey));
      await tester.pumpAndSettle();

      expect(api.byHand.single, ('reg-3', 'Main gate'));
    });

    testWidgets('someone already in is said to be, with no button',
        (tester) async {
      api.found = [
        guest(id: 'reg-3', checkedInAt: DateTime.utc(2026, 10, 25, 9)),
      ];
      await pump(tester);

      await tester.tap(find.text('Find'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GuestSearch.fieldKey), 'aarav');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GuestSearch.rowKey('reg-3')));
      await tester.pumpAndSettle();

      expect(find.text('Already checked in.'), findsOneWidget);
      expect(find.byKey(VolunteerScannerPage.guestCheckInKey), findsNothing);
    });
  });

  group('merch and store orders', () {
    setUp(() {
      api.context_ = gateContext(
        door: 'Main gate',
        permissions: const GatePermissions(checkIn: true, merch: true),
        hasMerch: true,
        hasStore: true,
      );
      api.found = [guest(id: 'reg-1')];
      api.merch = const AttendeeMerch(items: [
        MerchOwed(itemId: 'tee', name: 'T-shirt', status: 'COLLECTABLE'),
        MerchOwed(
          itemId: 'cap',
          name: 'Cap',
          status: 'NO_VARIANT_VALUE',
          choices: [(label: 'M', remaining: 3), (label: 'L', remaining: 0)],
        ),
        MerchOwed(itemId: 'bag', name: 'Bag', status: 'ALREADY_COLLECTED'),
      ]);
      api.orders = const [
        StoreOrder(
            id: 'o-1',
            status: 'paid',
            summary: '1 × Hoodie',
            lines: [(name: 'Hoodie', variant: 'L', qty: 1)]),
      ];
    });

    Future<void> openMerch(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('Merch'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GuestSearch.fieldKey).last, 'aarav');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GuestSearch.rowKey('reg-1')).last);
      await tester.pumpAndSettle();
    }

    testWidgets('shows what they are owed, and hands it over',
        (tester) async {
      await openMerch(tester);

      expect(api.merchCalls, ['reg-1']);
      expect(find.text('T-shirt'), findsOneWidget);
      expect(find.text('Already collected'), findsOneWidget);
      expect(find.text('No size on file — ask them, and tap it.'),
          findsOneWidget);

      await tester.tap(find.byKey(MerchHandover.handOverKey('tee')));
      await tester.pumpAndSettle();
      expect(api.collects.single, ('tee', 'reg-1', null));
      expect(find.text('Handed over: T-shirt.'), findsOneWidget);
    });

    testWidgets('a size picked at the door goes with the handover',
        (tester) async {
      await openMerch(tester);

      // None left in L: it can't be picked.
      await tester.tap(find.byKey(MerchHandover.sizeKey('cap', 'L')));
      await tester.pumpAndSettle();
      expect(api.collects, isEmpty);

      await tester.tap(find.byKey(MerchHandover.sizeKey('cap', 'M')));
      await tester.pumpAndSettle();
      expect(api.collects.single, ('cap', 'reg-1', 'M'));
    });

    testWidgets('a paid order from the shelf is handed over', (tester) async {
      await openMerch(tester);

      expect(find.text('1 × Hoodie'), findsOneWidget);
      await tester.ensureVisible(find.byKey(MerchHandover.orderKey('o-1')));
      await tester.tap(find.byKey(MerchHandover.orderKey('o-1')));
      await tester.pumpAndSettle();
      expect(api.handovers, ['o-1']);
    });
  });

  testWidgets('a volunteer with no switches on is told why there is nothing',
      (tester) async {
    api.context_ = gateContext(permissions: const GatePermissions());
    await pump(tester);

    expect(find.textContaining('has not switched on check-in or merch'),
        findsOneWidget);
    expect(find.text('Scan'), findsNothing);
  });

  group('typing a ticket code', () {
    testWidgets('checks the holder in, through the same door, and clears',
        (tester) async {
      api.scanAnswers.add(scanned(ScanOutcome.checkedIn, who: guest()));
      await pump(tester);

      await tester.tap(find.byKey(VolunteerScannerPage.typeCodeKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), _code);
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(api.scans.single.code, _code);
      expect(find.text('Aarav Menon — welcome in.'), findsOneWidget);
      expect(
          tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
          isEmpty);
    });

    testWidgets('nothing typed: asks for the code, and sends nothing',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(VolunteerScannerPage.typeCodeKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(find.text('Enter the ticket code'), findsOneWidget);
      expect(api.scans, isEmpty);
    });

    testWidgets('an admission number offers the by-hand check-in',
        (tester) async {
      api.scanAnswers.add(scanned(ScanOutcome.invalid,
          who: guest(id: 'reg-5', admissionNo: 'MOA-0042-E7'),
          hint: admissionNumberHint));
      await pump(tester);
      await tester.tap(find.byKey(VolunteerScannerPage.typeCodeKey));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'MOA-0042-E7');
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('admission no. MOA-0042-E7'), findsOneWidget);
      await tester.tap(find.byKey(GateOutcomeCard.byHandKey));
      await tester.pumpAndSettle();
      expect(api.byHand.single.$1, 'reg-5');
    });
  });
}
