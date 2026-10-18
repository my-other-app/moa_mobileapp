import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';

/// The switches as the settings screen shows them. [switches] is null until
/// they load, and stays null when the server keeps none -- then there is
/// nothing to show.
class PushSwitchesState {
  const PushSwitchesState({this.switches, this.error});

  final PushSwitches? switches;
  final String? error;
}

final pushSwitchesProvider =
    StateNotifierProvider.autoDispose<PushSwitchesNotifier, PushSwitchesState>(
  (ref) =>
      PushSwitchesNotifier(ref.watch(pushSettingsRepositoryProvider))..load(),
);

class PushSwitchesNotifier extends StateNotifier<PushSwitchesState> {
  PushSwitchesNotifier(this._repository) : super(const PushSwitchesState());

  final PushSettingsRepository _repository;

  Future<void> load() async {
    final result = await _repository.switches();
    if (!mounted) return;
    result.fold(
      (failure) => state = PushSwitchesState(error: failure.message),
      (switches) => state = PushSwitchesState(switches: switches),
    );
  }

  /// Turn one kind on or off: shown at once, put back if the server refuses.
  Future<void> set({bool? clubs, bool? topics, bool? platform}) async {
    final before = state.switches;
    if (before == null) return;
    state = PushSwitchesState(
      switches:
          before.copyWith(clubs: clubs, topics: topics, platform: platform),
    );
    final result = await _repository.setSwitches(
        clubs: clubs, topics: topics, platform: platform);
    if (!mounted) return;
    result.fold(
      (failure) =>
          state = PushSwitchesState(switches: before, error: failure.message),
      (saved) => state = PushSwitchesState(switches: saved),
    );
  }
}
