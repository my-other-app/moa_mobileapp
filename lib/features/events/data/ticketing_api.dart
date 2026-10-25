import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/ticketing.dart';

final ticketingApiProvider = Provider<TicketingApi>((ref) => TicketingApi());

/// The attendee's side of ticket types, discount codes, waiting lists and
/// offers (moa_backend `docs/TICKETING.md`). Through the app's one API
/// client, so the signed-in person's token goes along where the server
/// takes one (joining a list, claiming), and refusals arrive as
/// `ApiException`s with their `error_code`.
class TicketingApi {
  TicketingApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  static String _ref(Object event) =>
      Uri.encodeComponent(event.toString().trim());

  /// `GET /events/{ref}/ticket-types`: the types on sale and the viewer's
  /// places in line. [linked] also lists a hidden type a link named
  /// (`?ticket_type=`). Null from a server without ticket types.
  Future<EventTicketing?> ticketTypes(Object event, {int? linked}) async {
    final res = await _client.request(
      '/events/${_ref(event)}/ticket-types',
      DioMethod.get,
      param: linked == null ? null : {'ticket_type': linked},
    );
    return EventTicketing.fromJson(res.data);
  }

  /// `POST /events/{id}/discount-codes/check`: what [code] does to the
  /// price of [ticketTypeId]. Rate limited (10 a minute): a 429 throws.
  Future<DiscountQuote> checkCode(
    Object event, {
    required String code,
    int? ticketTypeId,
    String? email,
    String? phone,
  }) async {
    final res = await _client.request(
      '/events/${_ref(event)}/discount-codes/check',
      DioMethod.post,
      param: {
        'code': code.trim(),
        if (ticketTypeId != null) 'ticket_type_id': ticketTypeId,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    final quote = DiscountQuote.fromJson(res.data);
    if (quote == null) {
      throw const FormatException('The code check had no answer');
    }
    return quote;
  }

  /// `POST /events/{id}/waitlist`: a place in line for [ticketTypeId].
  Future<WaitlistEntry> joinWaitlist(
    Object event, {
    int? ticketTypeId,
    required String fullName,
    String? email,
    String? phone,
    bool whatsappOptIn = false,
  }) async {
    final res = await _client.request(
      '/events/${_ref(event)}/waitlist',
      DioMethod.post,
      param: {
        if (ticketTypeId != null) 'ticket_type_id': ticketTypeId,
        'full_name': fullName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (whatsappOptIn) 'whatsapp_opt_in': true,
      },
    );
    final entry = WaitlistEntry.fromJson(jsonObject(res.data) ?? const {});
    if (entry == null) {
      throw const FormatException('Joining the waiting list had no answer');
    }
    return entry;
  }

  /// `GET /events/{id}/waitlist/me`: the signed-in person's places in line.
  Future<List<WaitlistEntry>> myWaitlist(Object event) async {
    final res = await _client.request(
      '/events/${_ref(event)}/waitlist/me',
      DioMethod.get,
    );
    return [
      for (final item in jsonObjects(res.data))
        if (WaitlistEntry.fromJson(item) case final entry?) entry,
    ];
  }

  /// `DELETE /events/{id}/waitlist/me`: leave every place in line; how many.
  Future<int> leaveWaitlist(Object event) async {
    final res = await _client.request(
      '/events/${_ref(event)}/waitlist/me',
      DioMethod.delete,
    );
    return jsonInt(jsonObject(res.data)?['left']) ?? 0;
  }

  /// `GET /waitlist/offers/{token}`: what the claim link offers. The token is
  /// the credential; no session goes.
  Future<WaitlistOffer> offer(String token) async {
    final res = await _client.request(
      '/waitlist/offers/${Uri.encodeComponent(token)}',
      DioMethod.get,
      skipAuth: true,
    );
    final offer = WaitlistOffer.fromJson(res.data);
    if (offer == null) throw const FormatException('The offer had no event');
    return offer;
  }

  /// `POST /waitlist/offers/{token}/claim`: registers the person the place
  /// was offered to. The answer is the registration's; with the signed-in
  /// person's session when they are the offer's address.
  Future<RegistrationResult> claim(String token, {String? email}) async {
    final res = await _client.request(
      '/waitlist/offers/${Uri.encodeComponent(token)}/claim',
      DioMethod.post,
      param: {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
    return RegistrationResult.fromJson(res.data);
  }

  /// The event's public page's `event` (`GET /discover/events/{ref}`, a
  /// slug or an id): whether it was called off, and whether it is online.
  /// `/events/info` counts a view each time it is read, and a ticket list
  /// must not. The copy saved on the phone when there is no answer; null
  /// for an event that isn't public, or not known.
  Future<Map<String, dynamic>?> publicEvent(Object event) async {
    final path = '/discover/events/${_ref(event)}';
    Object? data;
    try {
      data = (await _client.request(path, DioMethod.get,
              skipAuth: true, cache: CachePolicy.shared))
          .data;
    } catch (_) {
      try {
        data = await _client.savedCopy(path);
      } catch (_) {
        data = null;
      }
    }
    return jsonObject(jsonObject(data)?['event']);
  }

  /// Whether the event at [event] was called off ([publicEvent]); null when
  /// not, or not known.
  Future<EventCancellation?> cancellationOf(Object event) async =>
      EventCancellation.of(await publicEvent(event));

  /// `POST /waitlist/offers/{token}/decline`: the place goes to the next
  /// person in line.
  Future<void> decline(String token) async {
    await _client.request(
      '/waitlist/offers/${Uri.encodeComponent(token)}/decline',
      DioMethod.post,
      skipAuth: true,
    );
  }
}
