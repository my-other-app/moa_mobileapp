import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/services/analytics_service.dart';

/// The "Share usage analytics" and "Send crash reports" switches in
/// Settings: what the person chose, saved on the phone and applied to the
/// SDKs at once.
///
/// Starts from the defaults (both on) and settles on the saved choices as
/// soon as they are read; start-up has already applied those
/// (`AnalyticsService.initialize`), so the switches only catch up.
final privacyChoicesProvider =
    StateNotifierProvider<PrivacyChoicesNotifier, PrivacyChoices>((ref) {
  return PrivacyChoicesNotifier(
    store: ref.watch(privacyChoicesStoreProvider),
    control: ref.watch(collectionControlProvider),
  );
});

class PrivacyChoicesNotifier extends StateNotifier<PrivacyChoices> {
  PrivacyChoicesNotifier({required this.store, required this.control})
      : super(PrivacyChoices.defaults) {
    _loaded = _load();
  }

  final PrivacyChoicesStore store;
  final CollectionControl control;

  late final Future<void> _loaded;

  /// Completes once the saved choices are in [state].
  Future<void> get loaded => _loaded;

  /// Set while a change is being made, so a tap during the first read is
  /// not overwritten by it.
  bool _changed = false;

  Future<void> _load() async {
    final saved = await store.read();
    if (!mounted || _changed) return;
    state = saved;
  }

  Future<void> setAnalytics(bool on) => _set(state.copyWith(analytics: on));

  Future<void> setCrashReports(bool on) =>
      _set(state.copyWith(crashReports: on));

  /// The switch moves at once; the choice is saved, then applied. A choice
  /// that cannot be saved still applies for this run.
  Future<void> _set(PrivacyChoices next) async {
    if (next == state) return;
    _changed = true;
    state = next;
    try {
      await store.write(next);
    } catch (e) {
      debugPrint('PrivacyChoices: could not save $next: $e');
    }
    await control.applyChoices(next);
  }
}
