import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';

/// The signed-in person's tickets on this phone, soonest first.
///
/// Starts from what is saved -- so a ticket opens with no network -- and is
/// brought up to date by [SavedTicketsNotifier.refresh], which
/// `SavedTicketsSync` calls whenever the app is online.
final savedTicketsProvider =
    StateNotifierProvider<SavedTicketsNotifier, List<SavedTicket>>((ref) {
  return SavedTicketsNotifier(ref.watch(savedTicketsRepositoryProvider));
});

class SavedTicketsNotifier extends StateNotifier<List<SavedTicket>> {
  SavedTicketsNotifier(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const []) {
    _loaded = _load();
  }

  final SavedTicketsRepository _repository;
  final DateTime Function() _now;

  late final Future<void> _loaded;
  Future<void>? _refreshing;
  DateTime? _lastRefresh;

  /// Done once the saved tickets have been read.
  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    final saved = await _repository.saved();
    // A refresh that finished first has the newer list.
    if (mounted && _lastRefresh == null) state = saved;
  }

  /// The saved ticket with [code], if there is one.
  SavedTicket? byCode(String code) {
    for (final ticket in state) {
      if (ticket.code == code) return ticket;
    }
    return null;
  }

  /// Bring the tickets up to date. One at a time; a failure (offline) keeps
  /// the saved ones.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() {
        _refreshing = null;
      });

  Future<void> _refresh() async {
    try {
      final fresh = await _repository.refresh();
      _lastRefresh = _now();
      if (mounted) state = fresh;
    } catch (e) {
      debugPrint('SavedTickets: refresh failed, keeping the saved ones: $e');
    }
  }

  /// [refresh], unless the last one was less than [age] ago.
  Future<void> refreshIfOlderThan(Duration age) {
    final last = _lastRefresh;
    if (last != null && _now().difference(last) < age) return Future.value();
    return refresh();
  }
}
