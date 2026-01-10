import 'dart:io';
import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_wallet_card/flutter_wallet_card.dart';
import 'package:intl/intl.dart';

/// Native Flutter ticket view page with QR code, download, calendar, share, and wallet features.
class TicketViewPage extends StatefulWidget {
  final String ticketId;
  final String eventName;
  final DateTime? eventDateTime;
  final String? locationName;
  final int? durationHours;
  final String? ticketUrl;
  final String? ticketHolderName;
  final String? ticketType;
  final String? posterUrl;

  const TicketViewPage({
    super.key,
    required this.ticketId,
    required this.eventName,
    this.eventDateTime,
    this.locationName,
    this.durationHours,
    this.ticketUrl,
    this.ticketHolderName,
    this.ticketType,
    this.posterUrl,
  });

  @override
  State<TicketViewPage> createState() => _TicketViewPageState();
}

class _TicketViewPageState extends State<TicketViewPage> {
  bool _isDownloading = false;
  bool _isAddingToWallet = false;

  String get _ticketWebUrl {
    if (widget.ticketUrl != null && widget.ticketUrl!.isNotEmpty) {
      if (widget.ticketUrl!.startsWith('http')) {
        return widget.ticketUrl!;
      }
      if (widget.ticketUrl!.startsWith('/api/v1/events/tickets/')) {
        final id =
            widget.ticketUrl!.replaceFirst('/api/v1/events/tickets/', '');
        return 'https://events.myotherapp.com/tickets/$id';
      }
    }
    return 'https://events.myotherapp.com/tickets/${widget.ticketId}';
  }

  String get _formattedDate {
    if (widget.eventDateTime == null) return 'TBA';
    return DateFormat('d MMM yyyy').format(widget.eventDateTime!).toUpperCase();
  }

  String get _formattedTime {
    if (widget.eventDateTime == null) return 'TBA';
    return DateFormat('h:mm a').format(widget.eventDateTime!);
  }

  Future<void> _downloadTicket() async {
    setState(() => _isDownloading = true);

    try {
      final pdfUrl =
          'https://api.myotherapp.com/api/v1/events/tickets/${widget.ticketId}/pdf';
      final response = await http.get(Uri.parse(pdfUrl));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/ticket_${widget.ticketId}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        setState(() => _isDownloading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ticket downloaded successfully!'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => OpenFilex.open(filePath),
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to download ticket');
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addToCalendar() async {
    if (widget.eventDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event date not available')),
      );
      return;
    }

    final Event event = Event(
      title: widget.eventName,
      description:
          'Event Ticket ID: ${widget.ticketId}\nLocation: ${widget.locationName ?? "TBA"}',
      location: widget.locationName ?? '',
      startDate: widget.eventDateTime!,
      endDate:
          widget.eventDateTime!.add(Duration(hours: widget.durationHours ?? 2)),
      iosParams: const IOSParams(reminder: Duration(hours: 1)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    try {
      await Add2Calendar.addEvent2Cal(event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event added to calendar!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add to calendar: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareTicket() async {
    await Share.share(
      'Check out my ticket for ${widget.eventName}!\n\n$_ticketWebUrl',
      subject: 'Ticket for ${widget.eventName}',
    );
  }

  Future<void> _addToWallet() async {
    setState(() => _isAddingToWallet = true);

    try {
      // For now, show a message that wallet integration requires backend setup
      // In production, this would fetch a .pkpass file from the backend
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet integration coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() => _isAddingToWallet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00BCD4), // Teal background
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BCD4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'YOUR TICKET',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareTicket,
            tooltip: 'Share Ticket',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Main Ticket Card
              _buildTicketCard(),
              const SizedBox(height: 24),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top section with event details (dark background)
            _buildTicketTop(),

            // Dotted divider
            _buildDottedDivider(),

            // Bottom section with QR code (light background)
            _buildTicketBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketTop() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        image: widget.posterUrl != null
            ? DecorationImage(
                image: NetworkImage(widget.posterUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.7),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Name
          Text(
            widget.eventName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Date and Time Row
          Row(
            children: [
              Expanded(
                child: _buildInfoColumn('Date', _formattedDate),
              ),
              Expanded(
                child: _buildInfoColumn('Time', _formattedTime),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location and Ticket ID Row
          Row(
            children: [
              Expanded(
                child:
                    _buildInfoColumn('Location', widget.locationName ?? 'TBA'),
              ),
              Expanded(
                child: _buildInfoColumn('Ticket ID', widget.ticketId),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ticket Holder and Type Row
          Row(
            children: [
              Expanded(
                child: _buildInfoColumn(
                  'Ticket Holder Name',
                  widget.ticketHolderName ?? 'Guest',
                ),
              ),
              Expanded(
                child: _buildInfoColumn(
                  'Ticket Type',
                  widget.ticketType ?? 'GENERAL',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDottedDivider() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          // Left semicircle cutout
          Container(
            width: 20,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF00BCD4),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),

          // Dotted line
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    (constraints.constrainWidth() / 10).floor(),
                    (index) => Container(
                      width: 5,
                      height: 1,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                );
              },
            ),
          ),

          // Right semicircle cutout
          Container(
            width: 20,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF00BCD4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketBottom() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: QrImageView(
              data: widget.ticketId,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 16),

          // Scan instruction
          Text(
            'Scan this QR code at the venue',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Row 1: Download and Calendar
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: _isDownloading ? Icons.hourglass_empty : Icons.download,
                label: _isDownloading ? 'Downloading...' : 'Download',
                onPressed: _isDownloading ? null : _downloadTicket,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.calendar_today,
                label: 'Add to Calendar',
                onPressed: _addToCalendar,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Add to Wallet (Full Width)
        SizedBox(
          width: double.infinity,
          child: _WalletButton(
            isLoading: _isAddingToWallet,
            onPressed: _addToWallet,
          ),
        ),
      ],
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C333D),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }
}

/// Add to Wallet button
class _WalletButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _WalletButton({
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.wallet, size: 20),
      label: Text(
        isLoading ? 'Adding to Wallet...' : 'Add to Wallet',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    );
  }
}
