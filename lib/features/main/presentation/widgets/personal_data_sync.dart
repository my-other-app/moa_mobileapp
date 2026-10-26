import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/services/push_arrivals.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:finnet/features/notifications/presentation/providers/push_settings_provider.dart';

/// Reads the person's notification switches and the first page of their
/// inbox ahead of the screens that show them, so Settings and the inbox
/// open on current data instead of filling in a round trip later.
///
/// Sits around the signed-in screens (the main shell), next to
/// `SavedTicketsSync`. It reads both when it first appears and when someone
/// signs in; again when the app comes back to the front (at most every
/// [resumeEvery]); and the inbox again whenever a push arrives while the
/// app is open ([arrivals]) -- the person's requests for a place too, once
/// read. Signed out it asks nothing.
///
/// The switches and the inbox each read their saved copy first and keep it
/// on screen if the network cannot be reached, so on a weak signal this
/// costs nothing but the attempt.
class PersonalDataSync extends ConsumerStatefulWidget {
  const PersonalDataSync({
    super.key,
    required this.child,
    this.arrivals,
    this.resumeEvery = const Duration(minutes: 5),
    this.now,
  });

  final Widget child;

  /// Defaults to [PushArrivals.count].
  final ValueListenable<int>? arrivals;
  final Duration resumeEvery;

  /// The clock, for tests.
  final DateTime Function()? now;

  @override
  ConsumerState<PersonalDataSync> createState() => _PersonalDataSyncState();
}

class _PersonalDataSyncState extends ConsumerState<PersonalDataSync>
    with WidgetsBindingObserver {
  late final ValueListenable<int> _arrivals;
  DateTime? _lastSync;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _arrivals = widget.arrivals ?? PushArrivals.count;
    _arrivals.addListener(_onPush);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _arrivals.removeListener(_onPush);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _signedIn => ref.read(isAuthenticatedProvider);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final last = _lastSync;
    if (last == null || _now().difference(last) >= widget.resumeEvery) {
      _sync();
    }
  }

  void _onPush() {
    if (!mounted || !_signedIn) return;
    ref.read(notificationsProvider.notifier).prefetch();
    // A club may have confirmed or declined a request: My events' "Waiting
    // for confirmation" and the event's button read it again -- once the
    // list has been read at all this session, and the server has it.
    final requests = ref.read(myRegistrationRequestsProvider);
    if (requests.loaded && requests.supported) {
      ref.read(myRegistrationRequestsProvider.notifier).refresh();
    }
  }

  void _sync() {
    if (!mounted || !_signedIn) return;
    _lastSync = _now();
    // Reading the switches' notifier is what starts them, the first time:
    // the saved copy, then the server.
    ref.read(pushSwitchesProvider.notifier).refresh();
    ref.read(notificationsProvider.notifier).prefetch();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isAuthenticatedProvider, (was, now) {
      if (now && was != true) _sync();
    });
    return widget.child;
  }
}
