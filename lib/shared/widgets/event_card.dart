import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart'
    show ticketRoute;
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:finnet/shared/widgets/svg_icon.dart';
import 'package:share_plus/share_plus.dart';

/// Status type for event cards
enum EventCardStatus {
  none, // Default - show "TAKE A CLOSER LOOK"
  registered, // Registered but event not over - show "VIEW TICKET"
  attended, // Event over and attended - show "VIEW CERTIFICATE"
  notAttended, // Event over but not attended - show "Not Attended" badge
  awaitingPayment, // Registered for a paid event, not paid - "FINISH PAYMENT"
}

/// The card status for an event this person is registered for:
/// [EventCardStatus.awaitingPayment] when its fee is still owed
/// ([isAwaitingPayment]: `has_fee` true and `is_paid` false; a missing
/// `is_paid` is not read as unpaid), else [EventCardStatus.registered].
EventCardStatus registeredCardStatus(Map<dynamic, dynamic> item) =>
    isAwaitingPayment(item)
        ? EventCardStatus.awaitingPayment
        : EventCardStatus.registered;

/// The small "Payment due" pill: on an awaiting-payment card, and on search
/// results for an unpaid registration.
class PaymentDueBadge extends StatelessWidget {
  const PaymentDueBadge({super.key});

  static const color = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('payment-due-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payments_outlined, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Payment due',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final String title;
  final String organizer;

  /// The event's poster map from the API (`{thumbnail, medium, large,
  /// original}`) or a single URL. Without one -- every upcoming event
  /// today -- the card draws the event's cover instead.
  final Object? poster;

  /// The category's id and name, the start and whether it is online: what
  /// the drawn cover shows when there is no poster.
  final Object? categoryId;
  final String? categoryName;
  final DateTime? startsAt;
  final bool isOnline;

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
  final bool showShareIcon;

  /// What FINISH PAYMENT does on an [EventCardStatus.awaitingPayment] card,
  /// when the list wants to know it happened (to fetch itself again after).
  /// Without it the button opens the event page straight into paying.
  final VoidCallback? onFinishPayment;

  const EventCard({
    super.key,
    required this.title,
    required this.organizer,
    this.poster,
    this.categoryId,
    this.categoryName,
    this.startsAt,
    this.isOnline = false,
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
    this.showShareIcon = true,
    this.onFinishPayment,
  });

  /// The event's public page, or null with neither a slug nor an id to
  /// link to (the share button is then left out).
  String? get _shareUrl => eventSlug.trim().isNotEmpty || eventId > 0
      ? eventShareUrl(id: eventId, slug: eventSlug)
      : null;

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
                child: ClipOval(
                  // Logos are presigned too: AppNetworkImage keys the cache
                  // on the object, not the signature, or it never hits.
                  child: AppNetworkImage(
                    url: orgImage,
                    width: 48,
                    height: 48,
                    errorWidget: (_) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.group, color: Colors.grey),
                    ),
                    placeholder: (_) => ColoredBox(color: Colors.grey[300]!),
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
            if (showShareIcon && _shareUrl != null)
              // A Builder so the share sheet can anchor to the icon (iPad).
              Builder(
                builder: (iconContext) => GestureDetector(
                  key: const ValueKey('event-share'),
                  onTap: () => _share(iconContext),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0).copyWith(right: 0),
                    child: SvgIcon(svgIconPath: AssetResources.share),
                  ),
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
              child: EventPosterImage(
                poster: poster,
                eventId: eventId,
                categoryId: categoryId,
                categoryName: categoryName,
                startsAt: startsAt,
                isOnline: isOnline,
                width: double.infinity,
                height: size.height * 0.5,
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            if (status == EventCardStatus.awaitingPayment)
              const Positioned(top: 12, right: 12, child: PaymentDueBadge())
            // Status badge overlay
            else if (status != EventCardStatus.none)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 16,
                        color: _getStatusTextColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusTextColor(status),
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
          onPressed: () {
            // The ticket inside the app, from what the phone has saved: it
            // used to open the website in the browser, which needs a signal
            // the door often does not have.
            final code = ticketCodeFromUrl(ticketUrl);
            if (code != null) {
              context.push(ticketRoute(code));
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
            final url = Uri.tryParse(certificateUrl ?? '');
            if (url != null && url.hasScheme) {
              // The site's certificate page: inside the app.
              if (isOwnSite(url)) {
                await openInAppThenBrowser(url);
              } else {
                await openExternally(url);
              }
            } else {
              context.push('/events/$eventId', extra: _getNavigationExtras());
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2C333D),
          ),
          child: const Text('VIEW CERTIFICATE'),
        );
      case EventCardStatus.notAttended:
        return FilledButton(
          onPressed: () {
            context.push('/events/$eventId', extra: _getNavigationExtras());
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2C333D),
          ),
          child: const Text('VIEW EVENT'),
        );
      case EventCardStatus.awaitingPayment:
        return FilledButton(
          key: const ValueKey('event-finish-payment'),
          onPressed: onFinishPayment ??
              () {
                // The event page starts the payment when it arrives with
                // this.
                context.push('/events/$eventId',
                    extra: {'status': finishPaymentStatus});
              },
          style: FilledButton.styleFrom(
            backgroundColor: PaymentDueBadge.color,
            foregroundColor: Colors.white,
          ),
          child: const Text('FINISH PAYMENT'),
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

  /// Share the event's public page through the system share sheet.
  Future<void> _share(BuildContext iconContext) async {
    final url = _shareUrl;
    if (url == null) return;
    final box = iconContext.findRenderObject() as RenderBox?;
    final name = title.trim();
    try {
      await Share.share(
        name.isEmpty ? url : '$name on MyOtherApp: $url',
        subject: name.isEmpty ? null : name,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      debugPrint('Event share failed: $e');
      if (!iconContext.mounted) return;
      ScaffoldMessenger.maybeOf(iconContext)?.showSnackBar(
        const SnackBar(content: Text("Couldn't open sharing. Try again.")),
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

  /// Get color for status badge
  Color _getStatusColor(EventCardStatus status) {
    switch (status) {
      case EventCardStatus.attended:
        return const Color(0xFF4CAF50); // Green
      case EventCardStatus.registered:
        return const Color(0xFFFFD600); // Yellow
      case EventCardStatus.notAttended:
        return const Color(0xFFF44336); // Red
      case EventCardStatus.awaitingPayment:
        return PaymentDueBadge.color;
      case EventCardStatus.none:
        return Colors.transparent;
    }
  }

  /// Get icon for status badge
  IconData _getStatusIcon(EventCardStatus status) {
    switch (status) {
      case EventCardStatus.attended:
        return Icons.verified;
      case EventCardStatus.registered:
        return Icons.confirmation_number;
      case EventCardStatus.notAttended:
        return Icons.cancel_outlined;
      case EventCardStatus.awaitingPayment:
        return Icons.payments_outlined;
      case EventCardStatus.none:
        return Icons.circle;
    }
  }

  /// Get text color for status badge
  Color _getStatusTextColor(EventCardStatus status) {
    switch (status) {
      case EventCardStatus.attended:
      case EventCardStatus.notAttended:
      case EventCardStatus.awaitingPayment:
        return Colors.white;
      case EventCardStatus.registered:
        return Colors.black87;
      case EventCardStatus.none:
        return Colors.transparent;
    }
  }

  /// Get text for status badge
  String _getStatusText(EventCardStatus status) {
    switch (status) {
      case EventCardStatus.attended:
        return 'Attended';
      case EventCardStatus.registered:
        return 'Registered';
      case EventCardStatus.notAttended:
        return 'Not Attended';
      case EventCardStatus.awaitingPayment:
        return 'Payment due';
      case EventCardStatus.none:
        return '';
    }
  }
}
