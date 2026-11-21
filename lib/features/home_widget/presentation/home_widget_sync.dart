import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/home_widget/data/next_up_store.dart';
import 'package:finnet/features/home_widget/domain/next_up.dart';

/// Writes "Next up" for the home-screen widgets (docs/HOME_WIDGETS.md).
///
/// Given what the app knows -- signed in or not, the tickets on the phone,
/// the registrations under review -- it works out what the widget shows
/// ([nextUpFrom]) and keeps it in the widgets' storage, which redraws them.
/// The same thing twice is written once.
class HomeWidgetSync {
  HomeWidgetSync(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final NextUpStore _store;
  final DateTime Function() _now;
  String? _written;

  /// Show [snapshot].
  Future<void> show(NextUpSnapshot snapshot) {
    final json = jsonEncode(snapshot.toJson(_now()));
    if (json == _written) return Future.value();
    _written = json;
    return _store.write(json);
  }

  /// Show what [signedIn], [tickets] and [requests] add up to.
  Future<void> update({
    required bool signedIn,
    required List<SavedTicket> tickets,
    required List<RegistrationRequest> requests,
  }) =>
      show(nextUpFrom(
        signedIn: signedIn,
        tickets: tickets,
        requests: requests,
        now: _now(),
      ));

  /// "Sign in to see your next event": the session ended.
  Future<void> signedOut() => show(NextUpSnapshot.signedOut);

  /// Draw the widgets again (the app came back to the front): their
  /// relative lines move on with the clock.
  Future<void> redraw() => _store.redraw();

  /// Whether a widget is on a home screen, worth reading more for.
  Future<bool> isPlaced() => _store.isPlaced();
}

/// The app's [HomeWidgetSync], one per session (SessionScope).
final homeWidgetSyncProvider = Provider<HomeWidgetSync>(
    (ref) => HomeWidgetSync(ref.watch(nextUpStoreProvider)));

/// What signing out does to the widgets (SessionCaches): a fresh write of
/// the signed-out state, whichever session wrote last.
Future<void> showSignedOutOnWidgets(NextUpStore store) =>
    store.write(jsonEncode(NextUpSnapshot.signedOut.toJson(DateTime.now())));

/// Keeps the "Next up" widgets current while the app is open.
///
/// Sits around the tabs (the main shell), next to `SavedTicketsSync`, which
/// keeps the tickets on the phone current. Once the saved tickets have been
/// read it writes what the widget shows, and again whenever the tickets,
/// the registrations under review or the session change -- a registration
/// made, a ticket gone from the server's list, a sign-in -- and redraws the
/// widgets each time the app comes back to the front.
///
/// The registrations under review are read for the widget only when one is
/// on a home screen and someone is signed in (at most every [requestsEvery]);
/// otherwise the widget uses what My events last read.
class HomeWidgetSyncScope extends ConsumerStatefulWidget {
  const HomeWidgetSyncScope({
    super.key,
    required this.child,
    this.requestsEvery = const Duration(minutes: 10),
  });

  final Widget child;
  final Duration requestsEvery;

  @override
  ConsumerState<HomeWidgetSyncScope> createState() =>
      _HomeWidgetSyncScopeState();
}

class _HomeWidgetSyncScopeState extends ConsumerState<HomeWidgetSyncScope>
    with WidgetsBindingObserver {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The first write waits for the saved tickets to be read, so a start-up
  /// never shows "nothing coming up" for the moment before they are.
  Future<void> _start() async {
    if (!mounted) return;
    try {
      await ref.read(savedTicketsProvider.notifier).loaded;
    } catch (e) {
      debugPrint('HomeWidgetSync: saved tickets not read: $e');
    }
    if (!mounted) return;
    _started = true;
    _publish();
    unawaited(_readRequestsIfPlaced());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted || !_started) return;
    _publish();
    unawaited(ref.read(homeWidgetSyncProvider).redraw());
    unawaited(_readRequestsIfPlaced());
  }

  void _publish() {
    if (!mounted || !_started) return;
    final requests = ref.read(myRegistrationRequestsProvider);
    unawaited(ref.read(homeWidgetSyncProvider).update(
          signedIn: ref.read(isAuthenticatedProvider),
          tickets: ref.read(savedTicketsProvider),
          requests: requests.open,
        ));
  }

  Future<void> _readRequestsIfPlaced() async {
    if (!ref.read(isAuthenticatedProvider)) return;
    if (!await ref.read(homeWidgetSyncProvider).isPlaced()) return;
    if (!mounted || !ref.read(isAuthenticatedProvider)) return;
    await ref
        .read(myRegistrationRequestsProvider.notifier)
        .refreshIfOlderThan(widget.requestsEvery);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(savedTicketsProvider, (_, __) => _publish());
    ref.listen(myRegistrationRequestsProvider, (_, __) => _publish());
    ref.listen<bool>(isAuthenticatedProvider, (was, now) {
      _publish();
      if (now && was != true) unawaited(_readRequestsIfPlaced());
    });
    return widget.child;
  }
}
