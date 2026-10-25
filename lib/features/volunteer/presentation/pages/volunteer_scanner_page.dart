import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';
import 'package:finnet/features/volunteer/presentation/providers/gate_controller.dart';
import 'package:finnet/features/volunteer/presentation/widgets/gate_outcome_card.dart';
import 'package:finnet/features/volunteer/presentation/widgets/gate_sync_panel.dart';
import 'package:finnet/features/volunteer/presentation/widgets/guest_search.dart';
import 'package:finnet/features/volunteer/presentation/widgets/merch_handover.dart';

/// The door, on a volunteer's phone: the club dashboard's door console for
/// one event (`/events/{id}/gate/...`), with the switches the club gave
/// them.
///
///   * Scan: the camera, or a typed code. A ticket is checked in at once
///     and the answer says why when it is not. With no signal the scan is
///     saved on the phone and sent when the signal is back; the scans the
///     server then refuses are listed by name, with why.
///   * Find: a guest by name, email or ticket, checked in by hand.
///   * Merch: what a guest is owed -- swag and their orders from the shelf
///     -- handed over. Only with the merch switch, and something to hand
///     out.
class VolunteerScannerPage extends ConsumerStatefulWidget {
  final int eventId;
  final String eventName;
  final String clubName;

  const VolunteerScannerPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.clubName,
  });

  static const typeCodeKey = ValueKey('gate-type-code');

  /// A found guest's sheet: check in, and their merch.
  static const guestCheckInKey = ValueKey('guest-check-in');
  static const guestMerchKey = ValueKey('guest-merch');

  /// The same code seen again this soon is the same ticket still in front
  /// of the camera, not a second scan.
  static const sameCodeWindow = Duration(seconds: 5);

  /// How long an admission's card stays before the next scan.
  static const admitCardFor = Duration(seconds: 7);

  @override
  ConsumerState<VolunteerScannerPage> createState() =>
      _VolunteerScannerPageState();
}

class _VolunteerScannerPageState extends ConsumerState<VolunteerScannerPage>
    with WidgetsBindingObserver {
  late final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  String? _lastCode;
  DateTime? _lastAt;
  Timer? _cardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_camera.start());
      // Back in the app: send what was saved, if there is signal now.
      unawaited(_controller.drain());
    } else if (state == AppLifecycleState.paused) {
      unawaited(_camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cardTimer?.cancel();
    _camera.dispose();
    super.dispose();
  }

  GateController get _controller =>
      ref.read(gateControllerProvider(widget.eventId).notifier);

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;
    final now = DateTime.now();
    final last = _lastAt;
    if (code == _lastCode &&
        last != null &&
        now.difference(last) < VolunteerScannerPage.sameCodeWindow) {
      return;
    }
    if (ref.read(gateControllerProvider(widget.eventId)).busy) return;
    _lastCode = code;
    _lastAt = now;
    unawaited(_controller.scan(code));
  }

  void _onCard(GateCard? card) {
    _cardTimer?.cancel();
    if (card == null) return;
    final tone = card.card.tone;
    if (tone == GateTone.admit) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    // Admissions clear themselves, so the card never blocks the next scan;
    // anything needing a decision stays.
    if (tone == GateTone.admit || tone == GateTone.queued) {
      _cardTimer = Timer(VolunteerScannerPage.admitCardFor, () {
        if (mounted) _controller.dismissCard();
      });
    }
  }

  void _openTyped() {
    context.push('/volunteer/manual-entry/${widget.eventId}', extra: {
      'eventName': _eventName,
      'clubName': widget.clubName,
    });
  }

  String get _eventName {
    final name =
        ref.read(gateControllerProvider(widget.eventId)).context?.eventName;
    return name == null || name.trim().isEmpty ? widget.eventName : name;
  }

  Future<void> _openGuest(GateAttendee guest, GateContext? ctx) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _GuestSheet(
        eventId: widget.eventId,
        guest: guest,
        context: ctx,
        onCheckIn: () async {
          Navigator.of(sheet).pop();
          await _controller.checkInByHand(guest);
        },
        onMerch: ctx != null && ctx.handsOut
            ? () {
                Navigator.of(sheet).pop();
                _openMerch(guest, ctx);
              }
            : null,
      ),
    );
  }

  Future<void> _openMerch(GateAttendee guest, GateContext ctx) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.85,
          child: MerchHandover(
            eventId: widget.eventId,
            guest: guest,
            hasMerch: ctx.hasMerch,
            hasStore: ctx.hasStore,
            door: ctx.doorName,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gateControllerProvider(widget.eventId));
    ref.listen<GateCard?>(
        gateControllerProvider(widget.eventId).select((s) => s.card),
        (prev, next) {
      if (next != null && next.seq != prev?.seq) _onCard(next);
    });
    final ctx = state.context;
    final perms = ctx?.permissions;
    // Before the event is read (no signal at open), scanning still works:
    // the server holds the switches, and checks them when the scans arrive.
    final canCheckIn = perms == null || perms.checkIn;
    final tabs = <(String, Widget)>[
      if (canCheckIn) ('Scan', _scanTab(state)),
      if (canCheckIn)
        (
          'Find',
          GuestSearch(
            eventId: widget.eventId,
            onPick: (g) => _openGuest(g, ctx),
          ),
        ),
      if (ctx != null && ctx.handsOut)
        (
          'Merch',
          GuestSearch(
            eventId: widget.eventId,
            hint: 'Find who is collecting',
            onPick: (g) => _openMerch(g, ctx),
          ),
        ),
    ];
    final network = ref.watch(networkStatusProvider);

    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.isEmpty ? 1 : tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (ctx?.eventName.isNotEmpty == true
                        ? ctx!.eventName
                        : widget.eventName)
                    .toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'BebasNeue', fontSize: 22),
              ),
              Text(
                [
                  if (ctx?.checkedIn != null)
                    '${ctx!.checkedIn}${ctx.registered == null ? '' : ' of ${ctx.registered}'} in',
                  ctx?.doorName ?? 'Door',
                  if (ctx != null && !ctx.doorOpen) 'door shut',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          bottom: tabs.length > 1
              ? TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: const Color(0xFFFFFFA0),
                  tabs: [for (final t in tabs) Tab(text: t.$1)],
                )
              : null,
        ),
        body: Column(
          children: [
            if (state.contextError != null && ctx == null)
              _ContextProblem(
                message: state.contextError!,
                onRetry: _controller.load,
              ),
            ValueListenableBuilder<bool>(
              valueListenable: network.offline,
              builder: (_, offline, __) => GateSyncPanel(
                queued: state.queued,
                offline: offline,
                syncing: state.syncing,
                syncError: state.syncError,
                report: state.report,
                onSendNow: _controller.drain,
                onDone: _controller.dismissReport,
              ),
            ),
            Expanded(
              child: tabs.isEmpty
                  ? const _NothingToDo()
                  : tabs.length == 1
                      ? tabs.single.$2
                      : TabBarView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: [for (final t in tabs) t.$2],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanTab(GateState state) {
    final card = state.card;
    final result = card?.result;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
            child: MobileScanner(controller: _camera, onDetect: _onDetect),
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFFFA0), width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        if (state.busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (card != null) ...[
                  GateOutcomeCard(
                    key: ValueKey('gate-card-${card.seq}'),
                    card: card.card,
                    onClose: _controller.dismissCard,
                    onCheckInByHand: result != null && result.needsHandCheckIn
                        ? () => _controller.checkInByHand(result.attendee!)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: VolunteerScannerPage.typeCodeKey,
                    onPressed: _openTyped,
                    icon: const Icon(Icons.keyboard),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFFA0),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    label: const Text(
                      'TYPE A TICKET CODE',
                      style: TextStyle(fontSize: 20, fontFamily: 'BebasNeue'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextProblem extends StatelessWidget {
  const _ContextProblem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFFF7E0),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF6B4E00), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$message Scans are still saved and sent later.',
                style: const TextStyle(color: Color(0xFF6B4E00), fontSize: 13),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _NothingToDo extends StatelessWidget {
  const _NothingToDo();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The organiser has not switched on check-in or merch for you at '
            'this event. Ask them to, from the club dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

/// A guest found by name: who they are, and what can be done for them.
class _GuestSheet extends StatelessWidget {
  const _GuestSheet({
    required this.eventId,
    required this.guest,
    required this.context,
    required this.onCheckIn,
    this.onMerch,
  });

  final int eventId;
  final GateAttendee guest;
  final GateContext? context;
  final VoidCallback onCheckIn;
  final VoidCallback? onMerch;

  @override
  Widget build(BuildContext context) {
    final g = guest;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(g.name.isEmpty ? g.ticketId : g.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              [
                g.ticketId,
                if (g.admissionNo != null) 'Admission no. ${g.admissionNo}',
                if (g.email != null) g.email!,
              ].join(' · '),
              style: const TextStyle(color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 16),
            if (g.checkedIn)
              const Text('Already checked in.',
                  style: TextStyle(
                      color: Color(0xFF15803D), fontWeight: FontWeight.w700))
            else ...[
              if (!g.isPaid)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Not paid: take the payment at the desk first.',
                    style: TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ),
              FilledButton.icon(
                key: VolunteerScannerPage.guestCheckInKey,
                onPressed: onCheckIn,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Check in'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            if (onMerch != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: VolunteerScannerPage.guestMerchKey,
                onPressed: onMerch,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Merch and orders'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
