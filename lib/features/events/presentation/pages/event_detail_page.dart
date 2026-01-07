import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myotherapp/features/events/presentation/providers/events_provider.dart';
import 'package:myotherapp/features/events/domain/entities/event_entity.dart';

/// Event detail page showing full event information.
class EventDetailPage extends ConsumerStatefulWidget {
  final int eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  Timer? _countdownTimer;
  String _countdownText = '';
  bool _registrationClosed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventDetailProvider(widget.eventId).notifier).loadEventDetails();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(DateTime? regEndDate) {
    if (regEndDate == null) return;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = regEndDate.difference(DateTime.now());
      if (diff.isNegative) {
        setState(() {
          _registrationClosed = true;
          _countdownText = 'Registration Closed';
        });
        timer.cancel();
      } else {
        setState(() {
          final days = diff.inDays;
          final hours = diff.inHours % 24;
          final minutes = diff.inMinutes % 60;
          final seconds = diff.inSeconds % 60;
          _countdownText = days > 0
              ? '${days}d ${hours}h ${minutes}m'
              : '${hours}h ${minutes}m ${seconds}s';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventDetailProvider(widget.eventId));

    // Start countdown when event loads
    ref.listen(eventDetailProvider(widget.eventId), (prev, current) {
      if (current.event != null && prev?.event == null) {
        _startCountdown(current.event!.registrationEndDate);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildErrorState(state.error!)
              : state.event != null
                  ? _buildEventContent(state.event!, state)
                  : const Center(child: Text('Event not found')),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref
                  .read(eventDetailProvider(widget.eventId).notifier)
                  .loadEventDetails(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventContent(Event event, EventDetailState state) {
    return CustomScrollView(
      slivers: [
        // App Bar with poster
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration:
                  BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: event.poster?.original != null
                ? Image.network(event.poster!.original,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[200]))
                : Container(color: Colors.grey[200]),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event name
                Text(event.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Club info
                GestureDetector(
                  onTap: () => context.pushNamed('clubDetail',
                      pathParameters: {'clubId': event.club.id.toString()}),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200]),
                        child: event.club.logo?.thumbnail != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                    event.club.logo!.thumbnail!,
                                    fit: BoxFit.cover))
                            : const Icon(Icons.business, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Text(event.club.name,
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[700])),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag(event.category.name, const Color(0xFF17A58F)),
                    _buildTag(
                        event.isOnline ? 'Online' : 'Offline', Colors.blue),
                    _buildTag(
                        event.isFree ? 'Free' : '₹${event.registrationFee}',
                        Colors.orange),
                    if (event.hasPrize)
                      _buildTag('Prize: ₹${event.prizeAmount}', Colors.purple),
                  ],
                ),
                const SizedBox(height: 24),

                // Countdown
                if (_countdownText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _registrationClosed
                          ? Colors.red[50]
                          : const Color(0xFF17A58F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _registrationClosed ? Icons.timer_off : Icons.timer,
                            color: _registrationClosed
                                ? Colors.red
                                : const Color(0xFF17A58F)),
                        const SizedBox(width: 8),
                        Text(_countdownText,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _registrationClosed
                                    ? Colors.red
                                    : const Color(0xFF17A58F))),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Event details
                _buildDetailRow(Icons.calendar_today, 'Date',
                    _formatDate(event.eventDateTime)),
                _buildDetailRow(Icons.access_time, 'Duration',
                    '${event.durationHours} hours'),
                _buildDetailRow(
                  event.isOnline ? Icons.videocam : Icons.location_on,
                  'Location',
                  event.locationName,
                  onTap: event.locationLink != null
                      ? () => _launchUrl(event.locationLink!)
                      : null,
                ),
                const SizedBox(height: 24),

                // Description
                if (event.description != null) ...[
                  const Text('About',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(event.description!,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700], height: 1.5)),
                  const SizedBox(height: 24),
                ],

                // Contact
                const Text('Contact',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (event.contactPhone != null)
                  _buildDetailRow(Icons.phone, 'Phone', event.contactPhone!,
                      onTap: () => _launchUrl('tel:${event.contactPhone}')),
                if (event.contactEmail != null)
                  _buildDetailRow(Icons.email, 'Email', event.contactEmail!,
                      onTap: () => _launchUrl('mailto:${event.contactEmail}')),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          color: onTap != null
                              ? const Color(0xFF17A58F)
                              : Colors.black)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
