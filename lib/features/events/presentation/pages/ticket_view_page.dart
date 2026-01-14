import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:myotherapp/core/storage/secure_storage_service.dart';

/// Premium ticket page with stunning glow effects and Apple Wallet-like design.
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
    with TickerProviderStateMixin {
  bool _isDownloading = false;
  bool _isAddingToWallet = false;
  late AnimationController _glowController;
  late AnimationController _pulseController;

  // Design colors inspired by app theme
  static const _accentYellow = Color(0xFFF9FFA1);
  static const _accentGreen = Color(0xFFB8FF9F);
  static const _darkBg = Color(0xFF0A0A0F);
  static const _cardDark = Color(0xFF141419);
  static const _cardBorder = Color(0xFF2A2A35);

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
    return DateFormat('MMM d, yyyy')
        .format(widget.eventDateTime!)
        .toUpperCase();
  }

  String get _formattedTime {
    if (widget.eventDateTime == null) return 'TBA';
    return DateFormat('h:mm a').format(widget.eventDateTime!);
  }

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _downloadTicket() async {
    setState(() => _isDownloading = true);
    HapticFeedback.mediumImpact();

    try {
      final pdfUrl =
          'https://api.myotherapp.com/api/v1/events/tickets/${widget.ticketId}/pdf';
      final response = await http.get(Uri.parse(pdfUrl));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/ticket_${widget.ticketId}.pdf';
        await File(filePath).writeAsBytes(response.bodyBytes);

        HapticFeedback.heavyImpact();
        if (mounted) {
          _showSuccessSnackBar('Ticket saved!', () => OpenFilex.open(filePath));
        }
      } else {
        throw Exception('Download failed');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Download failed');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _addToCalendar() async {
    HapticFeedback.lightImpact();
    if (widget.eventDateTime == null) {
      _showErrorSnackBar('Event date not available');
      return;
    }

    final Event event = Event(
      title: widget.eventName,
      description: 'Ticket: ${widget.ticketId}\n$_ticketWebUrl',
      location: widget.locationName ?? '',
      startDate: widget.eventDateTime!,
      endDate:
          widget.eventDateTime!.add(Duration(hours: widget.durationHours ?? 2)),
      iosParams: const IOSParams(reminder: Duration(hours: 1)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    await Add2Calendar.addEvent2Cal(event);
  }

  Future<void> _shareTicket() async {
    HapticFeedback.lightImpact();
    await Share.share(
      '🎟️ ${widget.eventName}\n\n'
      '📅 $_formattedDate • $_formattedTime\n'
      '📍 ${widget.locationName ?? "TBA"}\n\n'
      '$_ticketWebUrl',
    );
  }

  Future<void> _addToWallet() async {
    setState(() => _isAddingToWallet = true);
    HapticFeedback.mediumImpact();

    try {
      // Get auth token from secure storage
      final storage = SecureStorageService();
      final token = await storage.getAccessToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to add to wallet')),
          );
        }
        return;
      }

      // Download .pkpass file with authentication
      final response = await http.get(
        Uri.parse(
          'https://api.myotherapp.com/api/v1/events/tickets/${widget.ticketId}/wallet.pkpass',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download wallet pass');
      }

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ticket-${widget.ticketId}.pkpass');
      await file.writeAsBytes(response.bodyBytes);

      // Open the file - iOS will automatically prompt to add to Wallet
      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done) {
        // Fallback if open fails
        if (mounted) _showWalletInfoDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to wallet: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToWallet = false);
    }
  }

  void _showWalletInfoDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentYellow.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wallet, color: _accentYellow, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Wallet Pass Coming Soon',
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Apple Wallet and Google Wallet passes will be available soon. '
              'For now, you can screenshot this ticket or use the share button.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: Colors.white.withAlpha(180),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDialogButton(
                    'Copy Ticket ID',
                    Icons.copy,
                    () {
                      Clipboard.setData(ClipboardData(text: widget.ticketId));
                      Navigator.pop(ctx);
                      _showSuccessSnackBar('Ticket ID copied!', null);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDialogButton(
                    'Share Ticket',
                    Icons.share,
                    () {
                      Navigator.pop(ctx);
                      _shareTicket();
                    },
                    isPrimary: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogButton(String label, IconData icon, VoidCallback onTap,
      {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? _accentYellow : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: isPrimary ? Colors.black : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message, VoidCallback? onAction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'DMSans')),
        backgroundColor: _cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: onAction != null
            ? SnackBarAction(
                label: 'Open', textColor: _accentYellow, onPressed: onAction)
            : null,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'DMSans')),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Animated background glow
          _buildAnimatedBackground(),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildTicketCard(),
                    const SizedBox(height: 28),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: _buildAppBarButton(
          Icons.arrow_back_ios_new, () => Navigator.pop(context)),
      title: Column(
        children: [
          Text(
            'E-TICKET',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 18,
              color: _accentYellow,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarButton(Icons.share_outlined, _shareTicket),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Positioned(
          top: -100 + (_glowController.value * 20),
          left: 0,
          right: 0,
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  _accentYellow
                      .withAlpha((40 * _glowController.value).toInt() + 10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTicketCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _accentYellow
                    .withAlpha((20 + 15 * _pulseController.value).toInt()),
                blurRadius: 40 + (10 * _pulseController.value),
                spreadRadius: -10,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: _cardDark,
            border: Border.all(color: _accentYellow.withAlpha(60), width: 1.5),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              _buildTicketHeader(),
              _buildTicketDetails(),
              _buildPerforationLine(),
              _buildQRSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentYellow.withAlpha(15),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ticket type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentYellow, _accentGreen],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.ticketType?.toUpperCase() ?? 'GENERAL',
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Event name
          Text(
            widget.eventName.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 32,
              color: Colors.white,
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketDetails() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // Date & Time
          _buildDetailRow(
            Icons.event_outlined,
            '$_formattedDate  •  $_formattedTime',
          ),
          const SizedBox(height: 16),

          // Location
          _buildDetailRow(
            Icons.location_on_outlined,
            widget.locationName ?? 'Location TBA',
          ),
          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _cardBorder,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Ticket holder & ID
          Row(
            children: [
              Expanded(
                  child: _buildInfoBox(
                      'ATTENDEE', widget.ticketHolderName ?? 'Guest')),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.ticketId));
                    HapticFeedback.lightImpact();
                    _showSuccessSnackBar('Ticket ID copied!', null);
                  },
                  child: _buildInfoBox('TICKET ID', widget.ticketId,
                      copyable: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accentYellow.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _accentYellow, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String label, String value, {bool copyable = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              if (copyable) ...[
                const Spacer(),
                Icon(Icons.copy_rounded,
                    size: 12, color: _accentYellow.withAlpha(150)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPerforationLine() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          // Left notch
          Container(
            width: 16,
            height: 32,
            decoration: BoxDecoration(
              color: _darkBg,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(16)),
            ),
          ),

          // Perforated line
          Expanded(
            child: CustomPaint(
              painter: _PerforationPainter(color: _cardBorder),
              size: const Size(double.infinity, 1),
            ),
          ),

          // Right notch
          Container(
            width: 16,
            height: 32,
            decoration: BoxDecoration(
              color: _darkBg,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white.withAlpha(3),
          ],
        ),
      ),
      child: Column(
        children: [
          // QR Code with glow
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha(30),
                  blurRadius: 20,
                ),
              ],
            ),
            child: QrImageView(
              data: widget.ticketId,
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1A1A1A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'SCAN FOR ENTRY',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 14,
              color: _accentYellow,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: _isDownloading
                    ? Icons.hourglass_top_rounded
                    : Icons.download_rounded,
                label: _isDownloading ? 'Saving...' : 'Download',
                onPressed: _isDownloading ? null : _downloadTicket,
                accentColor: _accentYellow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
                onPressed: _addToCalendar,
                accentColor: _accentYellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Wallet button
        _WalletButton(
          isLoading: _isAddingToWallet,
          onPressed: _addToWallet,
          gradientColors: [_accentYellow, _accentGreen],
        ),
      ],
    );
  }
}

/// Custom painter for perforation line
class _PerforationPainter extends CustomPainter {
  final Color color;

  _PerforationPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(math.min(startX + dashWidth, size.width), size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glassmorphic action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color accentColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed?.call();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
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

/// Premium gradient wallet button
class _WalletButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;

  const _WalletButton({
    required this.isLoading,
    required this.gradientColors,
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
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withAlpha(60),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.black),
                )
              else
                const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.black, size: 22),
              const SizedBox(width: 12),
              Text(
                isLoading ? 'Adding...' : 'Add to Wallet',
                style: const TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 18,
                  color: Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
