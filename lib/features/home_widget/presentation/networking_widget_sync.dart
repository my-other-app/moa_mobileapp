import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/home_widget/data/networking_store.dart';
import 'package:finnet/features/home_widget/data/widget_store.dart';
import 'package:finnet/features/home_widget/domain/networking.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// Writes what the "Networking" home-screen widget shows
/// (docs/HOME_WIDGETS.md). The same thing twice is written once.
class NetworkingWidgetSync {
  NetworkingWidgetSync(this._store);

  final WidgetStore _store;
  String? _written;

  /// Show [snapshot].
  Future<void> show(NetworkingSnapshot snapshot) {
    final json = jsonEncode(snapshot.toJson());
    if (json == _written) return Future.value();
    _written = json;
    return _store.write(json);
  }

  /// "Sign in to share your QR".
  Future<void> signedOut() => show(NetworkingSnapshot.signedOut);

  Future<void> redraw() => _store.redraw();

  /// Whether a Networking widget is on a home screen.
  Future<bool> isPlaced() => _store.isPlaced();
}

/// The app's [NetworkingWidgetSync], one per session (SessionScope).
final networkingWidgetSyncProvider = Provider<NetworkingWidgetSync>(
    (ref) => NetworkingWidgetSync(ref.watch(networkingStoreProvider)));

/// What signing out does to the Networking widget (SessionCaches): a fresh
/// write of the signed-out face -- no code, no name, no count -- whichever
/// session wrote last.
Future<void> showSignedOutOnNetworkingWidget(WidgetStore store) =>
    store.write(jsonEncode(NetworkingSnapshot.signedOut.toJson()));

/// Keeps the "Networking" widget current while the app is open.
///
/// Sits around the tabs (the main shell), beside `HomeWidgetSyncScope`. It
/// writes what the app already knows -- signed in or not, the code My QR
/// last read or replaced ([lastKnownQrProvider]), the person's name (their
/// public profile, else their account), the network's size whenever a page
/// of it is read ([knownNetworkCountProvider]) -- and again whenever one of
/// them changes; it redraws the widget each time the app comes back to the
/// front.
///
/// Only while a Networking widget is on a home screen (and someone is
/// signed in) does it ask the server anything for it: the code (`GET
/// /me/qr`, which makes one on the first ask -- the person put their QR on
/// their home screen), the account's name, and the network's size, kept
/// current through saves, removals and blocks and read again at most every
/// [refreshEvery] on a return to the app.
class NetworkingWidgetSyncScope extends ConsumerStatefulWidget {
  const NetworkingWidgetSyncScope({
    super.key,
    required this.child,
    this.refreshEvery = const Duration(minutes: 10),
  });

  final Widget child;
  final Duration refreshEvery;

  @override
  ConsumerState<NetworkingWidgetSyncScope> createState() =>
      _NetworkingWidgetSyncScopeState();
}

class _NetworkingWidgetSyncScopeState
    extends ConsumerState<NetworkingWidgetSyncScope>
    with WidgetsBindingObserver {
  bool _started = false;

  /// The account's profile, followed once it exists (it reads itself from
  /// the server when first asked for, so it isn't asked for here unless a
  /// widget is placed).
  ProviderSubscription<ProfileState>? _account;

  /// The network's size, kept read while a widget is placed.
  ProviderSubscription<AsyncValue<NetworkList>>? _count;
  DateTime? _countSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _account?.close();
    _count?.close();
    super.dispose();
  }

  void _start() {
    if (!mounted) return;
    _started = true;
    _publish();
    unawaited(_followIfPlaced());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted || !_started) return;
    _publish();
    unawaited(ref.read(networkingWidgetSyncProvider).redraw());
    unawaited(_followIfPlaced());
  }

  /// The person's name, as My QR shows it: their public profile's, else
  /// their account's -- only if the account's profile was read already.
  String? _name() {
    final public = ref.read(myProfileProvider).profile?.profile.fullName;
    if (public != null && public.trim().isNotEmpty) return public;
    if (!ref.exists(profileProvider)) return null;
    return ref.read(profileProvider).profile?.fullName;
  }

  void _followAccount() {
    if (_account != null || !ref.exists(profileProvider)) return;
    _account =
        ref.listenManual<ProfileState>(profileProvider, (_, __) => _publish());
  }

  void _publish() {
    if (!mounted || !_started) return;
    _followAccount();
    final signedIn = ref.read(isAuthenticatedProvider);
    unawaited(ref.read(networkingWidgetSyncProvider).show(
          NetworkingSnapshot.from(
            signedIn: signedIn,
            qrLink: signedIn ? ref.read(lastKnownQrProvider)?.url : null,
            name: signedIn ? _name() : null,
            networkCount: signedIn ? ref.read(knownNetworkCountProvider) : null,
          ),
        ));
  }

  /// With a widget on a home screen and someone signed in: read what it
  /// shows. Otherwise stop reading for it.
  Future<void> _followIfPlaced() async {
    if (!ref.read(isAuthenticatedProvider)) return _stopFollowing();
    final placed = await ref.read(networkingWidgetSyncProvider).isPlaced();
    if (!mounted) return;
    if (!placed || !ref.read(isAuthenticatedProvider)) return _stopFollowing();

    // The code: My QR's own read (kept for the session), tried again if it
    // failed earlier -- offline at start-up, say.
    if (ref.read(myQrProvider).hasError) ref.invalidate(myQrProvider);
    unawaited(ref.read(myQrProvider.future).then((_) {}, onError: (_) {}));

    // The account's name: read if nothing has yet.
    ref.read(profileProvider);
    _followAccount();

    // The network's size: kept alive, so whatever invalidates the network
    // reads it again; and again on a return after [refreshEvery].
    final now = DateTime.now();
    if (_count == null) {
      _count = ref.listenManual<AsyncValue<NetworkList>>(
          networkListProvider(networkCountQuery), (_, __) {});
      _countSince = now;
    } else if (now.difference(_countSince ?? now) >= widget.refreshEvery) {
      _countSince = now;
      ref.invalidate(networkListProvider(networkCountQuery));
    }
  }

  void _stopFollowing() {
    _count?.close();
    _count = null;
    _countSince = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isAuthenticatedProvider, (was, now) {
      _publish();
      if (now && was != true) unawaited(_followIfPlaced());
      if (!now) _stopFollowing();
    });
    ref.listen(lastKnownQrProvider, (_, __) => _publish());
    ref.listen(knownNetworkCountProvider, (_, __) => _publish());
    ref.listen(myProfileProvider, (_, __) => _publish());
    return widget.child;
  }
}
