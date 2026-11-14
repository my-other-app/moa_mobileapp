import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network.dart';

/// Someone's public page, by handle, as this viewer may see it. Read again
/// when the person signs in or out: what they may see changes.
final publicProfileProvider = FutureProvider.autoDispose
    .family<ProfileLookup, String>((ref, handle) {
  ref.watch(isAuthenticatedProvider);
  return ref.watch(profilesApiProvider).profile(handle);
});

/// The person's own page as a stranger sees it: asked for as nobody.
final strangerViewProvider = FutureProvider.autoDispose
    .family<ProfileLookup, String>((ref, handle) =>
        ref.watch(profilesApiProvider).profile(handle, anonymous: true));

/// The person's QR. Kept for the session (and on the phone), so it opens
/// at once and with no signal; read again after "Replace code".
final myQrProvider = FutureProvider<MyQr>((ref) {
  if (!ref.watch(isAuthenticatedProvider)) {
    throw StateError('Signed out: there is no code to show');
  }
  return ref.watch(profilesApiProvider).myQr();
});

/// One page of the network.
final networkListProvider = FutureProvider.autoDispose
    .family<NetworkList, NetworkQuery>((ref, query) {
  ref.watch(isAuthenticatedProvider);
  return ref.watch(networkApiProvider).list(query);
});

/// One person in the network, with every encounter.
final networkPersonProvider =
    FutureProvider.autoDispose.family<NetworkPerson, int>((ref, id) {
  ref.watch(isAuthenticatedProvider);
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
