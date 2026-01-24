import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myotherapp/features/volunteer/presentation/providers/volunteer_provider.dart';

/// Page showing events the user is volunteering for
class VolunteerEventsPage extends ConsumerStatefulWidget {
  const VolunteerEventsPage({super.key});

  @override
  ConsumerState<VolunteerEventsPage> createState() =>
      _VolunteerEventsPageState();
}

class _VolunteerEventsPageState extends ConsumerState<VolunteerEventsPage> {
  @override
  void initState() {
    super.initState();
    // Fetch volunteer events on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(volunteerProvider.notifier).fetchVolunteerEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final volunteerState = ref.watch(volunteerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "EVENTS YOU'RE VOLUNTEER",
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(volunteerState),
    );
  }

  Widget _buildBody(VolunteerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(volunteerProvider.notifier).fetchVolunteerEvents();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No volunteer events',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "You haven't been assigned as a volunteer for any events yet.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.events.length,
      itemBuilder: (context, index) {
        final event = state.events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(VolunteerEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to scanner page with event info
          context.push('/volunteer/scanner/${event.id}', extra: {
            'eventName': event.name,
            'clubName': event.clubName,
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Event poster/club logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: event.posterUrl ?? event.clubLogoUrl ?? '',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[200],
                    child: const Icon(Icons.event, color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFF2C333D),
                    child: Center(
                      child: Text(
                        event.name.isNotEmpty
                            ? event.name[0].toUpperCase()
                            : 'E',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.clubName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Tags row
                    Row(
                      children: [
                        _buildTag('Event'),
                        _buildTagDot(),
                        _buildTag(event.hasFee ? 'Paid' : 'Free'),
                        _buildTagDot(),
                        _buildTag(
                          DateFormat('MMM d').format(event.eventDatetime),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow icon
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildTagDot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '✦',
        style: TextStyle(fontSize: 6, color: Colors.black54),
      ),
    );
  }
}
