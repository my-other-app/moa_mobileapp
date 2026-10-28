import 'package:flutter/foundation.dart';
import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/core/utils/hours.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/event_cover.dart';

// Reading an event from a list response (`/events/list`, `/events/for-you`)
// for a card, without trusting any field to be there. The feeds used to read
// `event['club']['id']` -- a crash for an event whose club is gone -- and
// printed "null Hours" for an event without a length.

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _string(Object? value) => value is String ? value : '';

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

/// "2 Hours", "2.5 Hours", "1 Hour"; null when the length is missing, not a
/// number, or not positive -- the card then leaves it out.
String? eventLengthLabel(Object? hours) {
  final num? value =
      hours is num ? hours : (hours is String ? num.tryParse(hours) : null);
  if (value == null || value.isNaN || value <= 0) return null;
  return hoursLabel(value);
}

/// The tags under a card: category, online or offline, free or paid, and
/// the length when there is one. Empty ones are left out rather than drawn
/// as a star with nothing beside it.
///
/// A paid online event on an iPhone ([platform], the running one by
/// default) gets no "Paid": the iOS app doesn't sell it, and a price cue
/// reads as one (canSellInApp).
List<String> eventCardTags(Map<String, dynamic> event,
    {TargetPlatform? platform}) {
  final category = _string(_map(event['category'])['name']).trim();
  final length = eventLengthLabel(event['duration']);
  final online = event['is_online'] == true;
  final paid = event['has_fee'] == true;
  final sellable =
      canSellInApp(hasFee: paid, isOnline: online, platform: platform);
  return [
    if (category.isNotEmpty) category,
    online ? 'Online' : 'Offline',
    if (sellable) paid ? 'Paid' : 'Free',
    if (length != null) length,
  ];
}

/// The hosting club's id, or 0 when the event came without its club.
int eventClubId(Map<String, dynamic> event) =>
    _int(_map(event['club'])['id']) ?? 0;

/// The event's page on the public site: by slug, or by id when it has none.
String eventShareUrl({required int id, String? slug}) {
  final s = slug?.trim() ?? '';
  final path = s.isNotEmpty ? Uri.encodeComponent(s) : '$id';
  return '${AppConfig.publicSiteUrl}/events/$path';
}

/// A card for one event from a list response.
EventCard eventCardFromJson(
  Map<String, dynamic> event, {
  EventCardStatus status = EventCardStatus.none,
  String? ticketUrl,
  String? certificateUrl,
  bool showShareIcon = true,
  VoidCallback? onFinishPayment,
  EventCancellation? cancellation,
}) {
  final club = _map(event['club']);
  final category = _map(event['category']);
  final name = _string(event['name']);
  final organizer = _string(club['name']);
  return EventCard(
    clubSlug: _string(club['slug']),
    // The S3 dict, an older row's bare URL, or nothing.
    orgImage: imageUrlFrom(club['logo']) ?? '',
    title: name.isEmpty ? 'No Title' : name,
    organizer: organizer.isEmpty ? 'Unknown Organizer' : organizer,
    tags: eventCardTags(event),
    onTap: () {},
    poster: event['poster'],
    categoryId: category['id'],
    categoryName:
        category['name'] is String ? category['name'] as String : null,
    startsAt: parseEventStart(event['event_datetime']),
    isOnline: event['is_online'] == true,
    hasFee: event['has_fee'] == true,
    eventId: _int(event['id']) ?? 0,
    clubId: eventClubId(event),
    eventSlug: _string(event['slug']),
    status: status,
    ticketUrl: ticketUrl,
    certificateUrl: certificateUrl,
    showShareIcon: showShareIcon,
    onFinishPayment: onFinishPayment,
    // The row's own word, when the server puts it there; else the caller's.
    cancellation: cancellation ?? EventCancellation.of(event),
    paidTicket: event['has_fee'] == true && event['is_paid'] == true,
    // The club's "High demand" label, where the row says it (never on one
    // that has ended).
    highDemand: event['high_demand'] == true && event['status'] != 'ended',
  );
}
