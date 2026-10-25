import 'dart:convert';
import 'dart:math';

import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where [LiveIdentity] keeps what it remembers: the phone's secure storage
/// in the app, memory in tests.
abstract class LiveStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLiveStore implements LiveStore {
  SecureLiveStore(this._storage);
  final SecureStorageService _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryLiveStore implements LiveStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Who this phone is in a live room, for someone without an account.
///
/// One key per install, made once and kept in secure storage: sent as
/// `X-Live-Key` with every room call (the room counts one vote, one
/// question's authorship and one poll answer per key) and as the quiz's
/// `player_key` when joining (the same key is the same player). A signed-in
/// person's token goes with every call too (the app's Dio adds it), and the
/// server then counts the account instead -- one vote across their phones.
///
/// The player each quiz gave back is kept per event, so leaving the quiz and
/// coming back is "back in as Asha", not a second player.
class LiveIdentity {
  LiveIdentity(this._store, {Random? random})
      : _random = random ?? Random.secure();

  static const installKeyName = 'live_install_key';
  static String playerKeyName(int eventId) => 'live_player_$eventId';

  final LiveStore _store;
  final Random _random;
  Future<String>? _key;

  /// The install's key: 24 letters and digits (the server takes 8 to 64).
  Future<String> installKey() => _key ??= _loadKey();

  Future<String> _loadKey() async {
    try {
      final kept = await _store.read(installKeyName);
      if (kept != null && validKey(kept)) return kept;
    } catch (_) {
      // Storage unreadable: a key for this run, which is still one person.
    }
    final made = newKey(_random);
    try {
      await _store.write(installKeyName, made);
    } catch (_) {}
    return made;
  }

  /// The player this phone is in [eventId]'s quiz, if it joined.
  Future<QuizPlayer?> player(int eventId) async {
    try {
      final raw = await _store.read(playerKeyName(eventId));
      if (raw == null) return null;
      return QuizPlayer.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlayer(QuizPlayer player) async {
    try {
      await _store.write(
          playerKeyName(player.eventId), jsonEncode(player.toJson()));
    } catch (_) {}
  }

  Future<void> forgetPlayer(int eventId) async {
    try {
      await _store.delete(playerKeyName(eventId));
    } catch (_) {}
  }

  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String newKey(Random random) =>
      List.generate(24, (_) => _alphabet[random.nextInt(_alphabet.length)])
          .join();

  /// As the server checks it: 8 to 64 letters, digits, `-` and `_`.
  static bool validKey(String key) =>
      RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(key);
}

final liveIdentityProvider = Provider<LiveIdentity>((ref) {
  return LiveIdentity(SecureLiveStore(ref.watch(secureStorageServiceProvider)));
});
