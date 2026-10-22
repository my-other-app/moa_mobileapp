import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';

/// Where the discover lists are about, kept on this phone between launches
/// (the website keeps its place in the browser the same way).
abstract class DiscoverPlaceStore {
  /// The place kept, or null.
  DiscoverWhere? get place;

  /// Keeps [place]; null forgets it. Never throws: a place that could not
  /// be written is guessed again at the next launch.
  Future<void> keep(DiscoverWhere? place);
}

/// A place kept for this run of the app only.
class MemoryDiscoverPlaceStore implements DiscoverPlaceStore {
  MemoryDiscoverPlaceStore([this.place]);

  @override
  DiscoverWhere? place;

  @override
  Future<void> keep(DiscoverWhere? place) async => this.place = place;
}

/// The place as a small JSON file in the app's support directory, read
/// once at start ([open]) so the first list is already asked about it.
///
/// It belongs to the phone rather than to an account: signing out leaves
/// it alone, as it does the privacy choices.
class FileDiscoverPlaceStore implements DiscoverPlaceStore {
  FileDiscoverPlaceStore._(this._directory, this._place);

  static const fileName = 'discover_place.json';

  /// The kept place, read from disk. Anything unreadable, or not a place,
  /// is none.
  static Future<FileDiscoverPlaceStore> open(
      {Future<Directory> Function()? directory}) async {
    final dir = directory ?? getApplicationSupportDirectory;
    DiscoverWhere? place;
    try {
      final file = File('${(await dir()).path}/$fileName');
      if (await file.exists()) {
        final read = parseWhere(jsonDecode(await file.readAsString()));
        if (read.isPlaced) place = read;
      }
    } catch (e) {
      debugPrint('DiscoverPlaceStore: could not read the place: $e');
    }
    return FileDiscoverPlaceStore._(dir, place);
  }

  final Future<Directory> Function() _directory;
  DiscoverWhere? _place;

  @override
  DiscoverWhere? get place => _place;

  @override
  Future<void> keep(DiscoverWhere? place) async {
    _place = place;
    try {
      final file = File('${(await _directory()).path}/$fileName');
      if (place == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      // Written aside and moved into place, so a crash halfway leaves the
      // old place rather than half a file.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(whereToJson(place)), flush: true);
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('DiscoverPlaceStore: could not keep the place: $e');
    }
  }
}

/// The phone's store. `main.dart` opens the file before the first frame and
/// hands it to every session ([SessionScope]); on its own -- in tests --
/// a place is kept in memory only.
final discoverPlaceStoreProvider =
    Provider<DiscoverPlaceStore>((ref) => MemoryDiscoverPlaceStore());
