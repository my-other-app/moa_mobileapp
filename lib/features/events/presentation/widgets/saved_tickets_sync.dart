import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';

/// Keeps the person's saved tickets current while the app is online.
///
/// Sits around the signed-in screens (the main shell). It refreshes the
/// tickets when it first appears, when the app comes back to the front
/// (at most every [resumeEvery]), and the moment the app is back online
/// after being offline -- so the ticket on the phone at the door is the
/// latest one the server gave, and one cancelled since is gone. Signed
/// out there are no tickets to ask about: it asks nothing until someone
/// signs in, and then at once.
class SavedTicketsSync extends ConsumerStatefulWidget {
  const SavedTicketsSync({
    super.key,
    required this.child,
    this.status,
    this.resumeEvery = const Duration(minutes: 10),
  });

  final Widget child;

  /// Defaults to [NetworkStatus.instance].
  final NetworkStatus? status;
  final Duration resumeEvery;

  @override
  ConsumerState<SavedTicketsSync> createState() => _SavedTicketsSyncState();
}

class _SavedTicketsSyncState extends ConsumerState<SavedTicketsSync>
    with WidgetsBindingObserver {
  late final ValueListenable<bool> _offline;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _offline = (widget.status ?? NetworkStatus.instance).offline;
    _wasOffline = _offline.value;
    _offline.addListener(_onNetworkChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _offline.removeListener(_onNetworkChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onNetworkChanged() {
    final offline = _offline.value;
    if (_wasOffline && !offline) _refresh();
    _wasOffline = offline;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _signedIn) {
      ref.read(savedTicketsProvider.notifier).refreshIfOlderThan(widget.resumeEvery);
    }
  }

  bool get _signedIn => ref.read(isAuthenticatedProvider);

  void _refresh() {
    if (!mounted || !_signedIn) return;
    ref.read(savedTicketsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isAuthenticatedProvider, (was, now) {
      if (now && was != true) _refresh();
    });
    return widget.child;
  }
}
