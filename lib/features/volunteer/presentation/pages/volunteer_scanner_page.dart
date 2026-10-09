import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finnet/features/volunteer/presentation/providers/volunteer_provider.dart';

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

    // Validate ticket only - don't mark as attended yet
    final result = await ref
        .read(volunteerProvider.notifier)
        .validateTicket(widget.eventId, ticketId);

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
    });

    // Show bottom sheet with result
    _showResultBottomSheet(result, ticketId);
  }

  void _showResultBottomSheet(CheckinResult result, String ticketId) {
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
          });
        },
        onGrantEntry: result.success
            ? () async {
                // Actually check in the user now
                Navigator.pop(context);

                setState(() {
                  _isProcessing = true;
                });

                final checkinResult = await ref
                    .read(volunteerProvider.notifier)
                    .checkinParticipant(widget.eventId, ticketId);

                if (!mounted) return;

                setState(() {
                  _isProcessing = false;
                  _showResult = false;
                });

                // Show success confirmation
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(checkinResult.success
                        ? 'Entry granted successfully!'
                        : 'Failed to check in: ${checkinResult.message}'),
                    backgroundColor:
                        checkinResult.success ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            : null,
      ),
    ).whenComplete(() {
      setState(() {
        _showResult = false;
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
                            fontSize: 24,
                            fontFamily: 'BebasNeue',
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
                    fontSize: 24,
                    fontFamily: 'BebasNeue',
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
      case CheckinResultType.incorrectEvent:
        return _buildIncorrectEventContent();
      case CheckinResultType.notPermitted:
        // Not the attendee's problem: this volunteer has no permission for
        // this event. Say so, rather than blaming their ticket.
        return _buildRefusalContent(
          icon: Icons.lock_outline,
          tint: Colors.orange,
          title: 'NOT YOUR EVENT',
          body: result.message,
        );
      case CheckinResultType.unreachable:
        // The scan never reached the server, so nothing is known about the
        // ticket. The close button already reads "SCAN ANOTHER".
        return _buildRefusalContent(
          icon: Icons.wifi_off,
          tint: Colors.blueGrey,
          title: 'NO ANSWER',
          body: result.message,
        );
    }
  }

  /// One refusal screen, parameterised.
  ///
  /// The four screens above predate this and are left as they are rather
  /// than folded in, so their pixels do not move.
  Widget _buildRefusalContent({
    required IconData icon,
    required MaterialColor tint,
    required String title,
    required String body,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: tint[50],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: tint[400], size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        _buildCloseButton(),
      ],
    );
  }

  /// Success - Valid ticket with details
  Widget _buildSuccessContent(BuildContext context) {
    // Format date and time from result
    String dateStr = 'N/A';
    String timeStr = 'N/A';
    if (result.eventDate != null) {
      dateStr =
          '${result.eventDate!.day}/${result.eventDate!.month}/${result.eventDate!.year}';
    }
    if (result.eventTime != null) {
      timeStr = result.eventTime!;
    }

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
        // Ticket holder name prominently displayed
        Text(
          result.ticketHolderName?.toUpperCase() ?? 'UNKNOWN',
          style: const TextStyle(
            fontSize: 20,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Email
        Text(
          result.ticketHolderEmail ?? 'No email',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // Ticket details grid
        Row(
          children: [
            Expanded(
              child: _buildDetailItem('Date', dateStr),
            ),
            Expanded(
              child: _buildDetailItem('Time', timeStr),
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

  /// Incorrect Event - Ticket belongs to different event
  Widget _buildIncorrectEventContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error icon with exclamation marks
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.red[50],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '!!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red[400],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'INCORRECT EVENT',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result.message.contains(':')
              ? result.message.split(':').last.trim()
              : 'This ticket belongs to a\ndifferent event.',
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
