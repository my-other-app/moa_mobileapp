import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _showResult = false;
  CheckinResult? _result;

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
    if (_isProcessing || _showResult) return;

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
    });

    final result = await ref
        .read(volunteerProvider.notifier)
        .checkinParticipant(widget.eventId, ticketId);

    if (!mounted) return;

    // Provide haptic feedback
    if (result.success) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _isProcessing = false;
      _showResult = true;
      _result = result;
    });

    // Show bottom sheet with result
    _showResultBottomSheet(result);
  }

  void _showResultBottomSheet(CheckinResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _ResultBottomSheet(
        result: result,
        eventName: widget.eventName,
        onClose: () {
          Navigator.pop(context);
          setState(() {
            _showResult = false;
            _result = null;
          });
        },
        onGrantEntry: result.success
            ? () {
                Navigator.pop(context);
                setState(() {
                  _showResult = false;
                  _result = null;
                });
                // Show success confirmation briefly
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Entry granted successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            : null,
      ),
    ).whenComplete(() {
      setState(() {
        _showResult = false;
        _result = null;
      });
    });
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
                          widget.eventName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'BebasNeue',
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

/// Bottom sheet widget for displaying check-in results
class _ResultBottomSheet extends StatelessWidget {
  final CheckinResult result;
  final String eventName;
  final VoidCallback onClose;
  final VoidCallback? onGrantEntry;

  const _ResultBottomSheet({
    required this.result,
    required this.eventName,
    required this.onClose,
    this.onGrantEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (result.type) {
      case CheckinResultType.success:
        return _buildSuccessContent(context);
      case CheckinResultType.notFound:
        return _buildNotFoundContent();
      case CheckinResultType.alreadyScanned:
        return _buildAlreadyScannedContent();
      case CheckinResultType.unpaid:
        return _buildUnpaidContent();
    }
  }

  /// Success - Valid ticket with details
  Widget _buildSuccessContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green[50],
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        // Ticket details grid
        Row(
          children: [
            Expanded(
              child: _buildDetailItem('Date', 'TODAY'),
            ),
            Expanded(
              child: _buildDetailItem('Time', 'NOW'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDetailItem('Event', eventName),
            ),
            Expanded(
              child: _buildDetailItem('Ticket ID', result.ticketId ?? 'N/A'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Grant Entry button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onGrantEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C333D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'GRANT ENTRY',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'BebasNeue',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'BebasNeue',
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Ticket Not Found
  Widget _buildNotFoundContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.red[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close,
            color: Colors.red[300],
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'TICKET NOT FOUND',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The QR code does not match\nany registered ticket.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        _buildCloseButton(),
      ],
    );
  }

  /// Already Scanned
  Widget _buildAlreadyScannedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Already scanned icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sync,
            color: Colors.blue[300],
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'THIS TICKET HAS ALREADY BEEN SCANNED',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This ticket has already been scanned.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        _buildCloseButton(),
      ],
    );
  }

  /// Unpaid ticket
  Widget _buildUnpaidContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Warning icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.orange[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[400],
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'PAYMENT REQUIRED',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The user has not paid the fee.\nPlease verify the payment details.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        _buildCloseButton(),
      ],
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onClose,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.grey),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'SCAN ANOTHER',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
