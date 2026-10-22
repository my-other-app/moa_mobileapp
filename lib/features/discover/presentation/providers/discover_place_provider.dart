import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/discover/data/datasources/discover_place_store.dart';
import 'package:finnet/features/discover/domain/discover_cities.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';

/// The one place every discover list is about, and how many times the
/// person has changed it.
@immutable
class DiscoverPlaceState {
  const DiscoverPlaceState({this.place, this.changes = 0});

  /// A city the person picked, else the connection's first guess. Null
  /// until one is known: the server then places each request by the
  /// connection as it comes.
  final DiscoverWhere? place;

  /// Counts the person's own changes (a city picked, a fresh guess asked
  /// for). The lists are read again when it moves, and only then: keeping
  /// the connection's guess changes nothing on screen, since the list that
  /// brought it already shows that place.
  final int changes;
}

/// Which place wins, in order:
///
/// 1. A city the person picked.
/// 2. The connection's first guess, kept. A later guess never replaces it
///    on its own: phones on mobile data sit behind their carrier's
///    addresses, which the server often places in another city (Mumbai,
///    Bengaluru, Chennai) than the phone's Wi-Fi at home.
/// 3. Nothing: each list is placed by the connection as it is asked for.
///
/// The app asks for no location permission (the owner's call), so there
/// is no device location to rank.
class DiscoverPlaceNotifier extends StateNotifier<DiscoverPlaceState> {
  DiscoverPlaceNotifier(this._store)
      : super(DiscoverPlaceState(place: _store.place));

  final DiscoverPlaceStore _store;

  /// The place now, if one is known.
  DiscoverWhere? get place => state.place;

  /// A list asked for without a point came back placed by the connection
  /// at [where]: kept, if nothing is known yet.
  void guessed(DiscoverWhere where) {
    if (state.place != null || where.source != WhereSource.ip) return;
    final point = where.point;
    if (point == null) return;
    final kept = DiscoverWhere(
      city: where.city,
      region: where.region,
      lat: point.lat,
      lng: point.lng,
      source: WhereSource.ip,
    );
    state = DiscoverPlaceState(place: kept, changes: state.changes);
    unawaited(_store.keep(kept));
  }

  /// The person picked [city]: it beats any guess.
  void pick(DiscoverCity city) {
    final place = city.where;
    state = DiscoverPlaceState(place: place, changes: state.changes + 1);
    unawaited(_store.keep(place));
  }

  /// Forget the place: the next list is placed by the connection again,
  /// and that guess is kept.
  void guessAgain() {
    state = DiscoverPlaceState(changes: state.changes + 1);
    unawaited(_store.keep(null));
  }
}

final discoverPlaceProvider =
    StateNotifierProvider<DiscoverPlaceNotifier, DiscoverPlaceState>(
        (ref) => DiscoverPlaceNotifier(ref.watch(discoverPlaceStoreProvider)));
