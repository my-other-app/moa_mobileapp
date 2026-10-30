import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/registration_status.dart';

/// What the ticket's own endpoint says about one ticket.
///
/// `GET /events/tickets/{code}` is all a person who opened their ticket from
/// a push, a deep link or the link in their email can ask: those routes
/// never read the list of registrations, which is where `ticket_revoked` has
/// always been, so the ticket screen was told nothing about a ticket the
/// organiser had taken back. Only that one field is read here, under the
/// name the list already uses for it.
class TicketDetails {
  const TicketDetails({required this.revoked});

  /// The organiser revoked it: the door refuses it, and so do its picture,
  /// its PDF and its Wallet pass.
  final bool revoked;

  /// The endpoint's body; null when it carried nothing to read.
  static TicketDetails? of(Object? body) {
    final json = jsonObject(body);
    if (json == null) return null;
    return TicketDetails(revoked: isTicketRevoked(json));
  }
}

/// Asks for a ticket's details, through the app's one client, so the
/// signed-in person's token goes with it. Null when the server will not say
/// -- it is older than the field, the ticket is not this person's (403), it
/// does not know the ticket (404), or there is no network. Null is "not
/// known", never "fine": nothing is taken away from the screen by it.
class TicketDetailsApi {
  TicketDetailsApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  Future<TicketDetails?> of(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    try {
      final res = await _client.request(
        '/events/tickets/${Uri.encodeComponent(trimmed)}',
        DioMethod.get,
      );
      return TicketDetails.of(res.data);
    } catch (e) {
      debugPrint('Ticket details of $trimmed: $e');
      return null;
    }
  }
}

final ticketDetailsApiProvider =
    Provider<TicketDetailsApi>((ref) => TicketDetailsApi());

/// One ticket's details, by code.
final ticketDetailsProvider =
    FutureProvider.autoDispose.family<TicketDetails?, String>((ref, code) {
  return ref.watch(ticketDetailsApiProvider).of(code);
});
