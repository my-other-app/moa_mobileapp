import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

/// Where the app goes as soon as it can, held until then.
///
/// Two things wait here, one at a time:
///
/// - a link that opened the app ([holdLaunch]): it arrives before the app
///   knows who is signed in, while the splash screen is up. Once the splash
///   has sent the person home, it opens over home -- so Back returns home --
///   or, if it needs an account and nobody is signed in, after sign-in;
/// - the page a sign-in should return to ([holdReturn]): the private page
///   someone was sent to sign in for, or the page they were on when an
///   action asked them to sign in. It opens once they are signed in and the
///   sign-in flow has brought them home.
///
/// Per session, like the router that reads it: a sign-out drops it.
class PendingLocation {
  String? _location;
  bool _fromLaunch = false;

  /// The location waiting, if any.
  String? get location => _location;

  /// Whether [location] is the link that opened the app, rather than a
  /// sign-in's return.
  bool get fromLaunch => _location != null && _fromLaunch;

  /// Hold the link the app was opened with. The first one wins: one launch
  /// comes from one link, and the router may report it more than once.
  void holdLaunch(String location) {
    if (_location != null) return;
    _location = location;
    _fromLaunch = true;
  }

  /// Hold where a sign-in returns to, replacing anything held: the newest
  /// sign-in is the one the person is in.
  void holdReturn(String location) {
    _location = location;
    _fromLaunch = false;
  }

  /// The held location, handed over exactly once.
  String? take() {
    final location = _location;
    clear();
    return location;
  }

  void clear() {
    _location = null;
    _fromLaunch = false;
  }
}

/// The session's [PendingLocation]. Read by the router and by the screens
/// that send someone to sign in.
final pendingLocationProvider =
    Provider<PendingLocation>((ref) => PendingLocation());

/// Opens what [pending] holds once [router] lands on Home -- where the
/// splash screen, the profile check and the end of onboarding all finish --
/// and it may open: always once signed in; signed out, only a link that
/// opened the app to a page open to everyone.
///
/// Returns the listener, added to the router's delegate; remove it when the
/// router goes.
VoidCallback openPendingOnHome(
  GoRouter router,
  ValueListenable<AuthState> auth,
  PendingLocation pending,
) {
  void open() {
    final location = pending.location;
    if (location == null) return;
    final here = router.routerDelegate.currentConfiguration;
    if (here.isEmpty) return;
    // Already there: the profile check took the person straight back to
    // `from` (an existing account), so there is nothing left to open.
    if (_same(here.uri, Uri.parse(location))) {
      pending.clear();
      return;
    }
    if (here.uri.path != '/') return;
    final now = auth.value;
    final ready = now.isAuthenticated ||
        (now.isInitialized && pending.fromLaunch && !needsAccount(location));
    if (!ready) return;
    pending.clear();
    // After this frame, once the router has settled on Home (as the splash
    // screen does with a tapped notification).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A tab is the page itself; anything else goes over Home, so Back
      // returns there.
      if (isTabRoot(location)) {
        router.go(location);
      } else {
        router.push(location);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  router.routerDelegate.addListener(open);
  return open;
}

bool _same(Uri a, Uri b) =>
    a.path.toLowerCase() == b.path.toLowerCase() &&
    mapEquals(a.queryParameters, b.queryParameters);
