import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

/// In-app ticket view page with download, calendar, and share features.
class TicketViewPage extends StatefulWidget {
  final String ticketId;
  final String eventName;
  final DateTime? eventDateTime;
  final String? locationName;
  final int? durationHours;
  final String? ticketUrl;

  const TicketViewPage({
    super.key,
    required this.ticketId,
    required this.eventName,
    this.eventDateTime,
    this.locationName,
    this.durationHours,
    this.ticketUrl,
  });

  @override
  State<TicketViewPage> createState() => _TicketViewPageState();
}

class _TicketViewPageState extends State<TicketViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isDownloading = false;

  String get _ticketWebUrl {
    // Use provided URL or construct from ticketId
    if (widget.ticketUrl != null && widget.ticketUrl!.isNotEmpty) {
      if (widget.ticketUrl!.startsWith('http')) {
        return widget.ticketUrl!;
      }
      // Handle relative URLs
      if (widget.ticketUrl!.startsWith('/api/v1/events/tickets/')) {
        final id =
            widget.ticketUrl!.replaceFirst('/api/v1/events/tickets/', '');
        return 'https://events.myotherapp.com/tickets/$id';
      }
    }
    return 'https://events.myotherapp.com/tickets/${widget.ticketId}';
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          const Color(0xFF00BCD4)) // Teal background like ticket
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error loading ticket: ${error.description}')),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(_ticketWebUrl));
  }

  Future<void> _downloadTicket() async {
    setState(() => _isDownloading = true);

    try {
      // Download PDF from backend
      final pdfUrl =
          'https://api.myotherapp.com/api/v1/events/tickets/${widget.ticketId}/pdf';

      final response = await http.get(Uri.parse(pdfUrl));

      if (response.statusCode == 200) {
        // Get downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/ticket_${widget.ticketId}.pdf';

        // Write file
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
      description: 'Event Ticket ID: ${widget.ticketId}',
      location: widget.locationName ?? '',
      startDate: widget.eventDateTime!,
      endDate: widget.eventDateTime!.add(
        Duration(hours: widget.durationHours ?? 2),
      ),
      iosParams: const IOSParams(
        reminder: Duration(hours: 1),
      ),
      androidParams: const AndroidParams(
        emailInvites: [],
      ),
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
    final ticketLink = _ticketWebUrl;
    await Share.share(
      'Check out my ticket for ${widget.eventName}!\n\n$ticketLink',
      subject: 'Ticket for ${widget.eventName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00BCD4), // Teal to match ticket design
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
      body: Column(
        children: [
          // WebView for ticket display
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),

          // Bottom action buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  // Download Button
                  Expanded(
                    child: _ActionButton(
                      icon: _isDownloading
                          ? Icons.hourglass_empty
                          : Icons.download,
                      label:
                          _isDownloading ? 'Downloading...' : 'Download Ticket',
                      onPressed: _isDownloading ? null : _downloadTicket,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add to Calendar Button
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.calendar_today,
                      label: 'Add to Calendar',
                      onPressed: _addToCalendar,
                    ),
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

/// Reusable action button widget
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
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2C333D),
        side: const BorderSide(color: Color(0xFF2C333D)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
