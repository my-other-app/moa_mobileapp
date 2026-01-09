import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/shared/widgets/svg_icon.dart';
import 'package:url_launcher/url_launcher.dart';

/// Status type for event cards
enum EventCardStatus {
  none, // Default - show "TAKE A CLOSER LOOK"
  registered, // Registered but event not over - show "VIEW TICKET"
  attended, // Event over and attended - show "VIEW CERTIFICATE"
}

class EventCard extends StatelessWidget {
  final String title;
  final String organizer;
  final String imageUrl;
  final List<String> tags;
  final VoidCallback onTap;
  final String orgImage;
  final int eventId;
  final int clubId;
  final String clubSlug;
  final String eventSlug;
  final EventCardStatus status;
  final String? ticketUrl;
  final String? certificateUrl;

  const EventCard({
    super.key,
    required this.title,
    required this.organizer,
    required this.imageUrl,
    required this.tags,
    required this.onTap,
    required this.orgImage,
    required this.eventId,
    required this.clubId,
    required this.clubSlug,
    required this.eventSlug,
    this.status = EventCardStatus.none,
    this.ticketUrl,
    this.certificateUrl,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                context.push('/clubs/$clubId', extra: {
                  'clubSlug': clubSlug,
                  'clubName': organizer,
                });
              },
              child: SizedBox(
                width: 48,
                height: 48,
                child: CachedNetworkImage(
                  imageUrl: orgImage,
                  imageBuilder: (context, imageProvider) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                    child: const Icon(Icons.group, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event title - tap to go to event page
                  InkWell(
                    onTap: () {
                      context.push('/events/$eventId',
                          extra: _getNavigationExtras());
                    },
                    child: Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Organizer - tap to go to club page
                  InkWell(
                    onTap: () {
                      context.push('/clubs/$clubId', extra: {
                        'clubSlug': clubSlug,
                        'clubName': organizer,
                      });
                    },
                    child: Text(
                      organizer,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final Uri url =
                    Uri.parse("https://events.myotherapp.com/$eventSlug");
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0).copyWith(right: 0),
                child: SvgIcon(svgIconPath: AssetResources.share),
              ),
            )
          ],
        ),

        /// Image with status badge
        Stack(
          children: [
            InkWell(
              onTap: () {
                context.push('/events/$eventId', extra: _getNavigationExtras());
              },
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                imageBuilder: (context, imageProvider) => Container(
                  height: size.height * 0.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                placeholder: (context, url) => Container(
                  height: size.height * 0.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: Colors.grey[300],
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
            // Status badge overlay
            if (status != EventCardStatus.none)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == EventCardStatus.attended
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFD600),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == EventCardStatus.attended
                            ? Icons.verified
                            : Icons.confirmation_number,
                        size: 16,
                        color: status == EventCardStatus.attended
                            ? Colors.white
                            : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status == EventCardStatus.attended
                            ? 'Attended'
                            : 'Registered',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status == EventCardStatus.attended
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        /// Tags
        Row(
          spacing: 16,
          children: tags.asMap().entries.map((entry) {
            int index = entry.key;
            String tag = entry.value;
            return Row(
              children: [
                if (index != 0) ...[
                  const SvgIcon(svgIconPath: AssetResources.star),
                  const SizedBox(width: 16),
                ],
                Text(
                  tag,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),

        // Action button based on status
        _buildActionButton(context),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    switch (status) {
      case EventCardStatus.registered:
        return FilledButton(
          onPressed: () async {
            if (ticketUrl != null && ticketUrl!.isNotEmpty) {
              final Uri url = Uri.parse(ticketUrl!);
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              context.push('/events/$eventId', extra: _getNavigationExtras());
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2C333D),
          ),
          child: const Text('VIEW TICKET'),
        );
      case EventCardStatus.attended:
        return FilledButton(
          onPressed: () async {
            if (certificateUrl != null && certificateUrl!.isNotEmpty) {
              final Uri url = Uri.parse(certificateUrl!);
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              context.push('/events/$eventId', extra: _getNavigationExtras());
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
          ),
          child: const Text('VIEW CERTIFICATE'),
        );
      case EventCardStatus.none:
        return FilledButton(
          onPressed: () {
            context.push('/events/$eventId', extra: _getNavigationExtras());
          },
          child: const Text('TAKE A CLOSER LOOK OF THE EVENT'),
        );
    }
  }

  /// Helper to get navigation extras with status info
  Map<String, dynamic> _getNavigationExtras() {
    return {
      'status': status.name,
      'ticketUrl': ticketUrl,
      'certificateUrl': certificateUrl,
    };
  }
}
