import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/auth/jwt_claims.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/cache/session_caches.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/profile/data/datasources/certificate_pin_store.dart';

/// This device's push registration, as signing in and out need it.
abstract class PushRegistration {
  /// Someone just signed in: ask for permission, then register.
  Future<void> onSignedIn();

  /// A stored session was restored at start-up: register, asking nothing.
  Future<void> onSessionRestored();

  /// Signing out, while the session is still good: ask the server to forget
  /// this device's push token. Runs before the session is revoked.
  Future<void> unregisterOnServer();

  /// The session ended: stop this device receiving that person's pushes.
  Future<void> onSignedOut();
}

/// [PushRegistration] through [NotificationService]. Every call is best
/// effort and never throws -- not even when Firebase failed to start, which
/// makes the [NotificationService] constructor itself throw.
class NotificationPushRegistration implements PushRegistration {
  const NotificationPushRegistration();

  @override
  Future<void> onSignedIn() =>
      _guard(() => NotificationService().requestPermissionAndRegister());

  @override
  Future<void> onSessionRestored() =>
      _guard(() => NotificationService().syncToken());

  @override
  Future<void> unregisterOnServer() =>
      _guard(() => NotificationService().unregisterOnServer());

  @override
  Future<void> onSignedOut() => _guard(() => NotificationService().unregister());

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      debugPrint('PushRegistration: $e');
    }
  }
}

/// Ends a session on the server.
abstract class SessionRevoker {
  /// End the session [accessToken] belongs to. Best effort; never throws.
  ///
  /// [stored]: [accessToken] is the app's stored session, so the call goes
  /// the normal way and the interceptor can refresh it once if it has
  /// expired. Otherwise -- a session sign-in opened and is refusing (a club
  /// account) -- the token is sent by hand and nothing is refreshed.
  Future<void> revoke(String accessToken, {bool stored = false});
}

/// `DELETE /auth/sessions/{sid}`, the session id read from the token.
///
/// Signing out used to delete the tokens on the phone and nothing else: the
/// session stayed live on the server, listed on the Security page, its
/// refresh token good for weeks.
class ApiSessionRevoker implements SessionRevoker {
  const ApiSessionRevoker();

  static const _timeout = Duration(seconds: 8);

  @override
  Future<void> revoke(String accessToken, {bool stored = false}) async {
    final sid = sessionIdOf(accessToken);
    // Tokens from before sessions existed carry no id. Ending every session
    // (`DELETE /auth/sessions`) would sign the person out on all devices,
    // which is not what one sign-out asks for.
    if (sid == null) return;
    try {
      await APIService.instance
          .request(
            '/auth/sessions/${Uri.encodeComponent(sid)}',
            DioMethod.delete,
            skipAuth: !stored,
            headers: stored ? null : {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);
      debugPrint('SessionRevoker: session ended on the server');
    } catch (e) {
      debugPrint('SessionRevoker: could not end the session: $e');
    }
  }
}

final pushRegistrationProvider = Provider<PushRegistration>(
  (ref) => const NotificationPushRegistration(),
);

final sessionRevokerProvider = Provider<SessionRevoker>(
  (ref) => const ApiSessionRevoker(),
);

/// Everything kept on the phone about the person: cleared at sign-out, when
/// the server ends the session, and at sign-in (so a second account never
/// sees the first one's tickets, registrations, profile, certificates,
/// PDFs or pictures). Posters and other public pictures stay.
final sessionCachesProvider = Provider<SessionCaches>((ref) {
  final tickets = ref.watch(savedTicketsLocalDataSourceProvider);
  final pins = ref.watch(certificatePinStoreProvider);
  return SessionCaches({
    'saved answers': () => ApiCache.instance.clear(),
    'saved tickets': tickets.clear,
    // Tickets' and certificates' renders and PDFs (TicketImages,
    // CertificateDocuments): one directory.
    'kept documents': () => DocumentCache.instance.clear(),
    'private pictures': AppImageCaches.clearPrivate,
    'certificate pins': pins.clear,
  });
});
