import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:myotherapp/features/volunteer/presentation/providers/volunteer_provider.dart';

/// QR Scanner page for volunteer check-in
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

  @override
  ConsumerState<VolunteerScannerPage> createState() =>
      _VolunteerScannerPageState();
}

class _VolunteerScannerPageState extends ConsumerState<VolunteerScannerPage>
    with WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _showSuccess = false;
  String? _successMessage;
  bool _showError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    } else if (state == AppLifecycleState.paused) {
      _scannerController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _showSuccess) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      _processTicket(code);
    }
  }

  Future<void> _processTicket(String ticketId) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _showError = false;
      _errorMessage = null;
    });

    final result = await ref
        .read(volunteerProvider.notifier)
        .checkinParticipant(widget.eventId, ticketId);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isProcessing = false;
        _showSuccess = true;
        _successMessage = result.message;
      });

      // Reset after showing success
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showSuccess = false;
            _successMessage = null;
          });
        }
      });
    } else {
      setState(() {
        _isProcessing = false;
        _showError = true;
        _errorMessage = result.message;
      });

      // Reset error after a delay
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showError = false;
            _errorMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),

          // Header overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(200),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and title row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '${widget.eventName.toUpperCase()}: SEAMLESS ENTRY, ZERO HASSLE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'BebasNeue',
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Scan instructions
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'SCAN QR CODE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'BebasNeue',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Hover over the QR Code on tickets',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scanning frame overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFFFFFA0),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // Success overlay
          if (_showSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.green.withAlpha(200),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _successMessage ?? 'Check-in successful!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Error overlay
          if (_showError)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'Check-in failed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFFFA0),
                  ),
                ),
              ),
            ),

          // Bottom button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              child: ElevatedButton(
                onPressed: () {
                  context.push('/volunteer/manual-entry/${widget.eventId}',
                      extra: {
                        'eventName': widget.eventName,
                        'clubName': widget.clubName,
                      });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFFA0),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ENTER TICKET CODE MANUALLY',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'BebasNeue',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
