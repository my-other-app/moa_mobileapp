import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';

/// Each ticket as the club designed it -- the server's render of the same
/// template, payload and engine as the emailed PDF, as a PNG -- kept on the
/// phone beside the PDFs ([DocumentCache]: the app's private files, deleted
/// at sign-out).
///
/// The ticket screen used to fetch the picture every time it opened and
/// keep nothing: offline, on a weak signal, or while a render was slow, it
/// fell back at once to the app's own drawn card, which looks nothing like
/// the ticket the club sent. Now the kept picture is shown at once, and
/// offline; the server is asked again with the kept copy's ETag, so an
/// unchanged ticket costs a 304.
///
/// [prefetch] keeps every upcoming ticket's picture ready before the event,
/// and deletes a revoked one's: a revoked ticket shows no QR of any kind.
class TicketImages {
  TicketImages({DocumentCache? cache, Duration? keepFor})
      : _cache = cache,
        keepFor = keepFor ?? const Duration(hours: 12);

  static TicketImages? _instance;

  /// The app's one, over [DocumentCache.instance].
  static TicketImages get instance => _instance ??= TicketImages();

  @visibleForTesting
  static set instance(TicketImages? images) => _instance = images;

  final DocumentCache? _cache;

  /// How long a complete kept picture is good for before [prefetch] asks
  /// the server again. Opening the ticket always asks.
  final Duration keepFor;

  DocumentCache get _documents => _cache ?? DocumentCache.instance;

  /// Where the picture of ticket [code] is kept.
  static String nameFor(String code) =>
      'ticket_${DocumentCache.safeName(code)}.png';

  /// The API's address for it.
  static String pathFor(String code) => '/events/tickets/$code/image';

  /// The kept picture of ticket [code], or null. Reads the disk only.
  Future<Uint8List?> saved(String code) async {
    final kept = await _documents.kept(nameFor(code));
    if (kept == null) return null;
    try {
      return await kept.file.readAsBytes();
    } catch (e) {
      debugPrint('TicketImages: could not read the kept $code: $e');
      return null;
    }
  }

  /// Ask the server for ticket [code]'s picture -- with the kept copy's
  /// ETag, so an unchanged one is a 304 -- and keep it. Offline, the kept
  /// copy marked not current; with none kept, the error.
  ///
  /// No second try on a failed connection: the person is probably at the
  /// door, and the kept copy (or the drawn card) is a ticket too.
  Future<({Uint8List bytes, bool current})> fetch(String code) async {
    final document = await _documents.fetch(
      pathFor(code),
      name: nameFor(code),
      extra: {RetryInterceptor.noRetryKey: true},
    );
    return (bytes: await document.file.readAsBytes(), current: document.current);
  }

  /// Delete ticket [code]'s kept picture.
  Future<void> forget(String code) => _documents.remove(nameFor(code));

  /// Bring the kept pictures in line with [tickets]: a revoked ticket's is
  /// deleted; one missing, incomplete or older than [keepFor] is fetched.
  /// One at a time, so the server -- which renders each one -- is not
  /// asked for them all at once. Failures are logged and skipped.
  Future<void> prefetch(List<SavedTicket> tickets, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    for (final ticket in tickets) {
      try {
        if (ticket.revoked) {
          await forget(ticket.code);
          continue;
        }
        final kept = await _documents.kept(nameFor(ticket.code));
        final fresh = kept != null &&
            kept.isFinal &&
            at.difference(kept.savedAt) < keepFor;
        if (fresh) continue;
        await fetch(ticket.code);
      } catch (e) {
        debugPrint('TicketImages: could not keep ${ticket.code}: $e');
      }
    }
  }
}

/// The app's [TicketImages]; overridden in tests.
final ticketImagesProvider =
    Provider<TicketImages>((ref) => TicketImages.instance);
