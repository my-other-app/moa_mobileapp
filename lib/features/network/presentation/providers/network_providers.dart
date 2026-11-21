import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/home/presentation/widgets/at_event_banner.dart'
    show checkedInNow;
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network.dart';

/// Someone's public page, by handle, as this viewer may see it. Read again
/// when the person signs in or out: what they may see changes.
final publicProfileProvider =
    FutureProvider.autoDispose.family<ProfileLookup, String>((ref, handle) {
  ref.watch(isAuthenticatedProvider);
  return ref.watch(profilesApiProvider).profile(handle);
});

/// The person's own page as a stranger sees it: asked for as nobody.
final strangerViewProvider = FutureProvider.autoDispose
    .family<ProfileLookup, String>((ref, handle) =>
        ref.watch(profilesApiProvider).profile(handle, anonymous: true));

/// The person's QR. Kept for the session (and on the phone), so it opens
/// at once and with no signal; read again after "Replace code". Each code
/// read is also [lastKnownQrProvider]'s.
final myQrProvider = FutureProvider<MyQr>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) {
    throw StateError('Signed out: there is no code to show');
  }
  final known = ref.read(lastKnownQrProvider.notifier);
  final qr = await ref.watch(profilesApiProvider).myQr();
  if (known.mounted) known.state = qr;
  return qr;
});

/// The person's QR as last read (or replaced) this session, asking the
/// server nothing: what the "Networking" home-screen widget draws
/// (lib/features/home_widget). Null until My QR -- or the widget, once it
/// is on a home screen -- reads it; cleared with the session.
final lastKnownQrProvider = StateProvider<MyQr?>((ref) {
  ref.watch(isAuthenticatedProvider);
  return null;
});

/// How many people are in the person's network, as last read this session:
/// for the "Networking" widget's "Network · 12". Set whenever a page of the
/// whole network (no search or filter) is read; null until one is.
final knownNetworkCountProvider = StateProvider<int?>((ref) {
  ref.watch(isAuthenticatedProvider);
  return null;
});

/// The smallest read that answers [knownNetworkCountProvider]: one person,
/// and the total. The Networking widget keeps it while it is on a home
/// screen, so a save, a removal or a block (each invalidates
/// [networkListProvider]) reads the count again.
const networkCountQuery = NetworkQuery(pageSize: 1);

/// One page of the network. Read again when the phone is back online: a
/// copy shown offline has no pictures (their links expire), the fresh one
/// does.
final networkListProvider = FutureProvider.autoDispose
    .family<NetworkList, NetworkQuery>((ref, query) async {
  ref.watch(isAuthenticatedProvider);
  ref.watch(backOnlineProvider);
  final count = ref.read(knownNetworkCountProvider.notifier);
  final list = await ref.watch(networkApiProvider).list(query);
  // The whole network's size, whatever the page or the order.
  if (!query.filtered && count.mounted) count.state = list.total;
  return list;
});

/// One person in the network, with every encounter; read again when the
/// phone is back online, as the list is.
final networkPersonProvider =
    FutureProvider.autoDispose.family<NetworkPerson, int>((ref, id) {
  ref.watch(isAuthenticatedProvider);
  ref.watch(backOnlineProvider);
  return ref.watch(networkApiProvider).person(id);
});

/// Who saved the person and hasn't been saved back; at one event, or all.
final savedMeProvider = FutureProvider.autoDispose
    .family<({List<SavedMeEntry> items, int total}), int?>((ref, eventId) {
  if (!ref.watch(isAuthenticatedProvider)) {
    return (items: const <SavedMeEntry>[], total: 0);
  }
  return ref.watch(networkApiProvider).savedMe(eventId: eventId);
});

/// The event the person is checked in to right now, if any -- from the
/// tickets on the phone, so it costs no request. Sent with a save; the
/// server records it only if the other person is checked in too.
final atEventIdProvider = Provider.autoDispose<int?>((ref) {
  if (!ref.watch(isAuthenticatedProvider)) return null;
  return checkedInNow(ref.watch(savedTicketsProvider), DateTime.now())?.eventId;
});
