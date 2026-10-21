import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/events/data/networking_repository.dart';
import 'package:finnet/features/events/domain/networking.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// People Like You for an event, by id: the list page and the event page's
/// card read the same answer, so a refresh on one shows on the other.
final networkingPeopleProvider =
    FutureProvider.autoDispose.family<NetworkingPeople, int>(
  (ref, eventId) => ref.watch(networkingRepositoryProvider).people(eventId),
);

/// "Show me in People Like You", as the switches show it.
class NetworkingVisibility {
  const NetworkingVisibility({this.visible, this.saving = false, this.error});

  /// On or off; null until known -- and from a server without the switch,
  /// when there is nothing to show.
  final bool? visible;

  /// A change is on its way to the server.
  final bool saving;

  /// Why the last change didn't stick.
  final String? error;
}

/// The switch in Settings and at the top of People Like You: one state, so
/// turning it off in one place shows in the other.
///
/// Starts from the profile (`networking_visible`, GET /user/profile/me) and
/// follows it; the list's own `visible` updates it too.
final networkingVisibilityProvider = StateNotifierProvider<
    NetworkingVisibilityNotifier, NetworkingVisibility>((ref) {
  final notifier = NetworkingVisibilityNotifier(
    ref.watch(networkingRepositoryProvider),
    initial: ref.read(profileProvider).profile?.networkingVisible,
    onSaved: (visible) =>
        ref.read(profileProvider.notifier).networkingVisibleSaved(visible),
  );
  ref.listen<bool?>(
    profileProvider.select((s) => s.profile?.networkingVisible),
    (_, next) => notifier.known(next),
  );
  return notifier;
});

class NetworkingVisibilityNotifier
    extends StateNotifier<NetworkingVisibility> {
  NetworkingVisibilityNotifier(
    this._repository, {
    bool? initial,
    void Function(bool visible)? onSaved,
  })  : _onSaved = onSaved,
        super(NetworkingVisibility(visible: initial));

  final NetworkingRepository _repository;
  final void Function(bool visible)? _onSaved;

  /// What the server says it is, from the profile or the list. Ignored
  /// while a change is being saved: the change is newer.
  void known(bool? visible) {
    if (visible == null || state.saving) return;
    state = NetworkingVisibility(visible: visible);
  }

  /// Turn it on or off: shown at once, put back if the server refuses.
  /// True when it stuck.
  Future<bool> set(bool visible) async {
    final before = state.visible;
    state = NetworkingVisibility(visible: visible, saving: true);
    try {
      final saved = await _repository.setVisible(visible);
      if (!mounted) return true;
      state = NetworkingVisibility(visible: saved);
      _onSaved?.call(saved);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = NetworkingVisibility(
        visible: before,
        error: readableError(
          e,
          fallback: "Couldn't change that. Try again in a moment.",
        ),
      );
      return false;
    }
  }
}
