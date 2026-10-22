import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';

/// The switches as the settings screen shows them.
///
/// Never blank while there is something to show: the server's answer once
/// it is in, the copy saved on this phone until then, and the server's
/// defaults (every kind on) on a phone that has never had either.
/// [switches] is null only on a server that keeps none -- then there is
/// nothing to change.
class PushSwitchesState {
  const PushSwitchesState({
    this.switches = PushSwitches.defaults,
    this.checked = false,
    this.saved = false,
    this.checkFailed = false,
  });

  final PushSwitches? switches;

  /// The server has answered (or confirmed a change) since the app started.
  final bool checked;

  /// [switches] is the copy saved on this phone, not yet checked.
  final bool saved;

  /// The last check could not reach the server.
  final bool checkFailed;

  /// Showing the defaults, with nothing saved and no answer yet: the first
  /// time Settings opens on this phone. The section says it is updating.
  bool get showingDefaults => !checked && !saved && switches != null;

  PushSwitchesState copyWith({
    PushSwitches? switches,
    bool? checked,
    bool? saved,
    bool? checkFailed,
  }) =>
      PushSwitchesState(
        switches: switches ?? this.switches,
        checked: checked ?? this.checked,
        saved: saved ?? this.saved,
        checkFailed: checkFailed ?? this.checkFailed,
      );
}

/// Lives for the session (a sign-out replaces the whole container), so the
/// switches read once -- at start-up, by `PersonalDataSync` -- are there
/// the moment Settings opens. It used to be autoDispose and start empty:
/// every visit to Settings began with the section missing, and the three
/// rows popped in a round trip later (~0.3 s on a warm connection to
/// us-east-1, ~1 s on a cold one, more when the access token had to be
/// refreshed first).
///
/// Read again when the app comes back online.
final pushSwitchesProvider =
    StateNotifierProvider<PushSwitchesNotifier, PushSwitchesState>((ref) {
  final notifier =
      PushSwitchesNotifier(ref.watch(pushSettingsRepositoryProvider));
  ref.listen<int>(backOnlineProvider, (_, __) {
    if (notifier.mounted) notifier.refresh();
  });
  return notifier;
});

class PushSwitchesNotifier extends StateNotifier<PushSwitchesState> {
  PushSwitchesNotifier(this._repository) : super(const PushSwitchesState()) {
    // Both at once: the saved copy is read off the phone in milliseconds,
    // and only shown if the server has not answered first.
    _readSaved();
    refresh();
  }

  final PushSettingsRepository _repository;

  Future<void>? _checking;

  /// Bumped by every change: a check that started before one is older than
  /// it, and is not shown.
  int _changes = 0;

  /// Changes sent and not yet answered.
  int _sending = 0;

  Future<void> _readSaved() async {
    PushSwitches? saved;
    try {
      saved = await _repository.savedSwitches();
    } catch (e) {
      debugPrint('PushSwitches: no saved copy: $e');
    }
    if (!mounted || saved == null) return;
    if (state.checked || _changes > 0) return;
    state = state.copyWith(switches: saved, saved: true);
  }

  /// Ask the server again, in the background. One at a time.
  Future<void> refresh() => _checking ??= _check().whenComplete(() {
        _checking = null;
      });

  Future<void> _check() async {
    final changes = _changes;
    final result = await _repository.switches();
    if (!mounted) return;
    // A change made while this was out is newer than its answer.
    if (_changes != changes || _sending > 0) return;
    result.fold(
      (failure) => state = state.copyWith(checkFailed: true),
      (switches) => state = PushSwitchesState(
        switches: switches,
        checked: true,
      ),
    );
  }

  /// Turn one kind on or off: shown at once, put back if the server
  /// refuses. Returns null when it stuck, else what to tell the person.
  Future<String?> set({bool? clubs, bool? topics, bool? platform}) async {
    final before = state.switches;
    if (before == null) return null;
    _changes++;
    _sending++;
    state = state.copyWith(
      switches:
          before.copyWith(clubs: clubs, topics: topics, platform: platform),
      checkFailed: false,
    );
    final result = await _repository.setSwitches(
        clubs: clubs, topics: topics, platform: platform);
    _sending--;
    if (!mounted) return null;
    return result.fold(
      (failure) {
        // Only what this change moved goes back: another switch turned
        // meanwhile keeps its own fate.
        final now = state.switches ?? before;
        state = state.copyWith(
          switches: PushSwitches(
            clubs: clubs != null ? before.clubs : now.clubs,
            topics: topics != null ? before.topics : now.topics,
            platform: platform != null ? before.platform : now.platform,
          ),
        );
        return failureMessage(failure);
      },
      (saved) {
        // The server's word, unless another change is still on its way:
        // its answer settles all three.
        if (_sending == 0) {
          state = PushSwitchesState(switches: saved, checked: true);
        }
        return null;
      },
    );
  }

  /// What to say when a change did not stick. Nothing is queued: a switch
  /// that looked on while the server still had it off would be worse.
  static String failureMessage(Failure failure) => failure is NetworkFailure
      ? "You're offline, so that wasn't changed. Try again when you're connected."
      : "Couldn't change that. Try again in a moment.";
}
