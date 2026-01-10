import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Enhanced native Flutter ticket view page matching app design.
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

class _TicketViewPageState extends State<TicketViewPage>
    with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  bool _isAddingToWallet = false;
  late AnimationController _shimmerController;

  // App theme colors
  static const _primaryDark = Color(0xFF2C333D);
  static const _accentYellow = Color(0xFFF9FFA1);
  static const _backgroundDark = Color(0xFF1A1A2E);
  static const _cardBackground = Color(0xFF0D0D14);

  String get _ticketWebUrl {
    if (widget.ticketUrl != null && widget.ticketUrl!.isNotEmpty) {
      if (widget.ticketUrl!.startsWith('http')) return widget.ticketUrl!;
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

  String get _formattedDay {
    if (widget.eventDateTime == null) return '';
    return DateFormat('EEEE').format(widget.eventDateTime!);
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ticket downloaded!'),
              backgroundColor: _primaryDark,
              action: SnackBarAction(
                label: 'Open',
                textColor: _accentYellow,
                onPressed: () => OpenFilex.open(filePath),
              ),
            ),
          );
        }
      } else {
        throw Exception('Download failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
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
          'Ticket ID: ${widget.ticketId}\n\nView ticket: $_ticketWebUrl',
      location: widget.locationName ?? '',
      startDate: widget.eventDateTime!,
      endDate:
          widget.eventDateTime!.add(Duration(hours: widget.durationHours ?? 2)),
      iosParams: const IOSParams(reminder: Duration(hours: 1)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    try {
      await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareTicket() async {
    await Share.share(
      '🎟️ ${widget.eventName}\n\n'
      '📅 $_formattedDate at $_formattedTime\n'
      '📍 ${widget.locationName ?? "TBA"}\n\n'
      'View my ticket: $_ticketWebUrl',
      subject: 'My ticket for ${widget.eventName}',
    );
  }

  Future<void> _addToWallet() async {
    setState(() => _isAddingToWallet = true);

    try {
      // Generate Apple Wallet pass URL
      final walletUrl = Uri.parse(
        'https://api.myotherapp.com/api/v1/events/tickets/${widget.ticketId}/wallet',
      );

      // Try to open the wallet pass
      if (await canLaunchUrl(walletUrl)) {
        await launchUrl(walletUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Copy ticket ID for manual entry
        await Clipboard.setData(ClipboardData(text: widget.ticketId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Wallet pass not available yet. Ticket ID copied!',
              ),
              backgroundColor: _primaryDark,
              action: SnackBarAction(
                label: 'OK',
                textColor: _accentYellow,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: widget.ticketId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ticket ID copied to clipboard!'),
            backgroundColor: _primaryDark,
          ),
        );
      }
    } finally {
      setState(() => _isAddingToWallet = false);
    }
  }

  void _copyTicketId() {
    Clipboard.setData(ClipboardData(text: widget.ticketId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ticket ID copied!'),
        backgroundColor: _primaryDark,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share_outlined,
                  color: Colors.white, size: 18),
            ),
            onPressed: _shareTicket,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _backgroundDark,
              _cardBackground,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  // Header text
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Main Ticket Card
                  _buildTicketCard(),
                  const SizedBox(height: 32),

                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'YOUR TICKET',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 28,
            color: _accentYellow,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Scan QR at venue for entry',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: Colors.white.withAlpha(150),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accentYellow.withAlpha(30),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top section - Event Details
            _buildTicketTop(),

            // Tear line with cutouts
            _buildTearLine(),

            // Bottom section - QR Code
            _buildTicketBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketTop() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBackground,
        border: Border(
          left: BorderSide(color: _accentYellow.withAlpha(100), width: 1),
          right: BorderSide(color: _accentYellow.withAlpha(100), width: 1),
          top: BorderSide(color: _accentYellow.withAlpha(100), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentYellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.ticketType?.toUpperCase() ?? 'GENERAL ADMISSION',
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Event Name
          Text(
            widget.eventName,
            style: const TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 28,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),

          // Date/Time Section with icon
          _buildInfoRow(
            Icons.calendar_today_outlined,
            '$_formattedDate  •  $_formattedTime',
            _formattedDay,
          ),
          const SizedBox(height: 12),

          // Location with icon
          _buildInfoRow(
            Icons.location_on_outlined,
            widget.locationName ?? 'To be announced',
            null,
          ),
          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _accentYellow.withAlpha(80),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Ticket holder and ID
          Row(
            children: [
              Expanded(
                child: _buildDetailColumn(
                  'TICKET HOLDER',
                  widget.ticketHolderName ?? 'Guest',
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _copyTicketId,
                  child: _buildDetailColumn(
                    'TICKET ID',
                    widget.ticketId,
                    showCopyIcon: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String primary, String? secondary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentYellow.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accentYellow, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (secondary != null)
                Text(
                  secondary,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    color: Colors.white.withAlpha(150),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailColumn(String label, String value,
      {bool showCopyIcon = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 10,
            color: Colors.white.withAlpha(120),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showCopyIcon) ...[
              const SizedBox(width: 4),
              Icon(Icons.copy, size: 12, color: _accentYellow.withAlpha(180)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTearLine() {
    return Container(
      color: _cardBackground,
      child: Row(
        children: [
          // Left cutout
          Container(
            width: 24,
            height: 48,
            decoration: BoxDecoration(
              color: _backgroundDark,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
          ),

          // Dotted line
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dashCount = (constraints.maxWidth / 12).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(dashCount, (i) {
                    return Container(
                      width: 6,
                      height: 2,
                      decoration: BoxDecoration(
                        color: _accentYellow.withAlpha(80),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          // Right cutout
          Container(
            width: 24,
            height: 48,
            decoration: BoxDecoration(
              color: _backgroundDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: _accentYellow.withAlpha(100), width: 1),
          right: BorderSide(color: _accentYellow.withAlpha(100), width: 1),
          bottom: BorderSide(color: _accentYellow.withAlpha(100), width: 1),
        ),
      ),
      child: Column(
        children: [
          // QR Code with glow effect
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primaryDark.withAlpha(30),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: QrImageView(
              data: widget.ticketId,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF2C333D),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF2C333D),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scan text
          Text(
            'SCAN FOR ENTRY',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 14,
              color: _primaryDark,
              letterSpacing: 2,
            ),
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
              child: _GlassButton(
                icon: _isDownloading
                    ? Icons.hourglass_top
                    : Icons.download_rounded,
                label: _isDownloading ? 'Saving...' : 'Download',
                onPressed: _isDownloading ? null : _downloadTicket,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassButton(
                icon: Icons.event_outlined,
                label: 'Calendar',
                onPressed: _addToCalendar,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Add to Wallet Button
        _WalletButton(
          isLoading: _isAddingToWallet,
          onPressed: _addToWallet,
          accentColor: _accentYellow,
        ),
      ],
    );
  }
}

/// Glassmorphic action button
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _GlassButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium wallet button with gradient
class _WalletButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color accentColor;

  const _WalletButton({
    required this.isLoading,
    required this.accentColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor,
                accentColor.withGreen(240),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              else
                const Icon(Icons.wallet, color: Colors.black, size: 22),
              const SizedBox(width: 10),
              Text(
                isLoading ? 'Adding to Wallet...' : 'Add to Wallet',
                style: const TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 18,
                  color: Colors.black,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
