import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The iPhone keychain as flutter_secure_storage 9 sees it: one entry a
/// key, each at an accessibility level. A read, a write and `containsKey`
/// find an entry whatever its level (a write rewrites it at the store's);
/// a delete and the listings (`readAll`, `deleteAll`) only see entries at
/// the store's own level -- which is why an older build's entries need
/// moving, or deleting at their own level.
class FakeIosKeychain {
  final entries = <String, ({String value, KeychainAccessibility level})>{};

  /// Levels whose `deleteAll` throws, as the keychain does before the
  /// phone's first unlock.
  final refusing = <KeychainAccessibility>{};

  /// The store at [level].
  FlutterSecureStorage at(KeychainAccessibility level) =>
      _LevelStore(this, level);

  void put(String key, String value, KeychainAccessibility level) =>
      entries[key] = (value: value, level: level);

  Map<String, String> valuesAt(KeychainAccessibility level) => {
        for (final e in entries.entries)
          if (e.value.level == level) e.key: e.value.value,
      };

  Map<String, String> get values =>
      {for (final e in entries.entries) e.key: e.value.value};
}

class _LevelStore implements FlutterSecureStorage {
  _LevelStore(this._keychain, this._level);

  final FakeIosKeychain _keychain;
  final KeychainAccessibility _level;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _keychain.entries[key]?.value;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _keychain.entries.remove(key);
    } else {
      _keychain.put(key, value, _level);
    }
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _keychain.entries.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_keychain.entries[key]?.level == _level) _keychain.entries.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _keychain.valuesAt(_level);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_keychain.refusing.contains(_level)) {
      throw Exception('errSecInteractionNotAllowed');
    }
    _keychain.entries.removeWhere((_, e) => e.level == _level);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
