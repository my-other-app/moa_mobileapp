import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:finnet/features/network/presentation/widgets/save_outcome_card.dart';

/// The camera, as the scanner page draws it: a function of what to call
/// with each code read. A test puts a button in its place.
typedef ScanCamera = Widget Function(
    BuildContext context, void Function(String raw) onCode);

/// The scanner's "Save a person" mode (`/network/scan`): point it at
/// someone's personal QR -- in their app, on their badge -- and they are
/// saved at once, with the event (when both are checked in to it) and the
/// time. With no signal the save is kept on the phone and sent later.
///
/// A ticket is never read here: "That's a ticket", and nothing about it.
class SavePersonScannerPage extends ConsumerStatefulWidget {
  const SavePersonScannerPage({super.key, this.eventId, this.camera});

  /// The event the person is at, when the scanner was opened from it.
  final int? eventId;

  /// Defaults to the phone's camera.
  final ScanCamera? camera;

  /// The same code read again this soon is the same scan.
  static const sameCodeWindow = Duration(seconds: 4);

  static const ticketMessage =
      "That's a ticket. Scan the person's QR from their app or badge.";
  static const otherMessage =
      "That isn't a MyOtherApp personal QR. Ask them to open My QR.";

  @override
  ConsumerState<SavePersonScannerPage> createState() =>
      _SavePersonScannerPageState();
}

class _SavePersonScannerPageState extends ConsumerState<SavePersonScannerPage>
    with WidgetsBindingObserver {
  MobileScannerController? _camera;
  SaveAttempt? _attempt;
  int _seq = 0;
  bool _busy = false;
  String? _lastCode;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    if (widget.camera == null) {
      _camera = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(networkSaverProvider.notifier).drain());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.resumed) {
      if (camera != null) unawaited(camera.start());
      unawaited(ref.read(networkSaverProvider.notifier).drain());
    } else if (state == AppLifecycleState.paused) {
      if (camera != null) unawaited(camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _onCode(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    final now = DateTime.now();
    final last = _lastAt;
    if (text == _lastCode &&
        last != null &&
        now.difference(last) < SavePersonScannerPage.sameCodeWindow) {
      return;
    }
    _lastCode = text;
    _lastAt = now;

    final scanned = readScannedCode(text);
    final SaveAttempt attempt;
    switch (scanned) {
      case TicketScanned():
        attempt = const SaveRefused(SavePersonScannerPage.ticketMessage);
      case OtherCode():
        attempt = const SaveRefused(SavePersonScannerPage.otherMessage);
      case PersonalCode(:final code):
        attempt = await _save(code: code);
      case ProfileHandleCode(:final handle):
        attempt = await _save(handle: handle);
    }
    if (!mounted) return;
    if (attempt is Saved || attempt is SavedLater) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.heavyImpact());
    }
    setState(() {
      _attempt = attempt;
      _seq++;
    });
  }

  Future<SaveAttempt> _save({String? code, String? handle}) async {
    setState(() => _busy = true);
    try {
      return await ref.read(networkSaverProvider.notifier).save(
            code: code,
            handle: handle,
            method: MetHow.qr,
            eventId: widget.eventId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _phoneCamera(BuildContext context, void Function(String) onCode) {
    return MobileScanner(
      controller: _camera,
      onDetect: (capture) {
        if (capture.barcodes.isEmpty) return;
        final raw = capture.barcodes.first.rawValue;
        if (raw != null) onCode(raw);
      },
      errorBuilder: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "The camera isn't available. Allow camera access for "
            "MyOtherApp in your phone's Settings.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(networkSaverProvider);
    final attempt = _attempt;
    final camera = widget.camera ?? _phoneCamera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SAVE A PERSON',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_camera != null)
            IconButton(
              tooltip: 'Torch',
              icon: const Icon(Icons.flashlight_on_outlined),
              onPressed: () => _camera!.toggleTorch(),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: camera(context, _onCode)),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF9FFA1), width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Text(
              widget.eventId == null
                  ? "Point at someone's personal QR"
                  : "Point at someone's personal QR. Saved with this event "
                      'when you are both checked in.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (_busy)
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (attempt != null)
                    SaveOutcomeCard(
                      key: ValueKey('save-card-$_seq'),
                      attempt: attempt,
                      onClose: () => setState(() => _attempt = null),
                    ),
                  if (pending.count > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        pending.count == 1
                            ? '1 save waiting for a signal'
                            : '${pending.count} saves waiting for a signal',
                        key: const ValueKey('scanner-pending'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push(myQrLocation),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Show my QR instead'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
