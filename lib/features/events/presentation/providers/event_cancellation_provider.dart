import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/domain/ticketing.dart';

/// Whether an event the person holds a ticket for was called off, for the
/// screens that have the ticket but not the event: My events' cards and the
/// ticket. The list of registrations and the ticket don't say it today, so
/// each event's public page is asked -- once in [keep], however often its
/// card is drawn, and only for the cards on screen.
class EventCancellationLookups {
  EventCancellationLookups._();

  static final instance = EventCancellationLookups._();

  /// How long an answer is trusted.
  static const keep = Duration(minutes: 10);

  final _asked = <String, (DateTime, Future<EventCancellation?>)>{};

  /// The event at [eventRef] (a slug or an id): its cancellation, or null.
  Future<EventCancellation?> of(String eventRef, {TicketingApi? api}) {
    final key = eventRef.trim();
    if (key.isEmpty || key == '0') return Future.value(null);
    final now = DateTime.now();
    final had = _asked[key];
    if (had != null && now.difference(had.$1) < keep) return had.$2;
    final asking = (api ?? TicketingApi()).cancellationOf(key).catchError(
      (Object e) {
        debugPrint('Cancellation of $key: $e');
        return null;
      },
    );
    _asked[key] = (now, asking);
    return asking;
  }

  /// Forget every answer (a sign-out; a test).
  @visibleForTesting
  void clear() => _asked.clear();
}

/// [EventCancellationLookups], for a screen with a ref.
final eventCancellationProvider = FutureProvider.autoDispose
    .family<EventCancellation?, String>((ref, eventRef) {
  return EventCancellationLookups.instance
      .of(eventRef, api: ref.watch(ticketingApiProvider));
});
