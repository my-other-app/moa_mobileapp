import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finnet/core/storage/secure_storage_service.dart';

/// One saved value and when it was last written, as a store lists it.
class StoredItem {
  const StoredItem(this.key, this.bytes, this.modified, {this.keep = false});

  final String key;
  final int bytes;
  final DateTime modified;

  /// Not to be deleted to make room ([CacheEntry.keep]).
  final bool keep;
}

/// How an encoded saved answer says it is kept (`CacheEntry.keep`). It is
/// written before the answer's data, so a listing finds it in the first
/// bytes without decoding the rest.
const cacheKeepMarker = '"keep":true';

/// Whether an encoded entry says it is kept ([cacheKeepMarker]).
bool _isKept(String value) {
  final head = value.length > 96 ? value.substring(0, 96) : value;
  return head.contains(cacheKeepMarker);
}

/// Where saved responses live: strings by key.
abstract class CacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Everything this store holds -- and only this store: never the tokens.
  Future<void> clear();

  /// What is held, for pruning by age and size.
  Future<List<StoredItem>> list();
}

/// In memory, for tests.
class MemoryCacheStore implements CacheStore {
  MemoryCacheStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final values = <String, String>{};
  final _modified = <String, DateTime>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    _modified[key] = _now();
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
    _modified.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
    _modified.clear();
  }

  @override
  Future<List<StoredItem>> list() async => [
        for (final entry in values.entries)
          StoredItem(entry.key, utf8.encode(entry.value).length,
              _modified[entry.key] ?? _now(),
              keep: _isKept(entry.value)),
      ];
}

/// Plain files under the app's cache directory, for what is the same for
/// everyone: event lists, an event's page, clubs, the topics. The system
/// may clear this directory when the phone is short of space; that only
/// means the next screen waits for the network.
class FileCacheStore implements CacheStore {
  FileCacheStore({Future<Directory> Function()? root})
      : _root = root ?? _defaultRoot;

  final Future<Directory> Function() _root;
  Directory? _dir;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationCacheDirectory()).path}/api_cache');

  Future<Directory> _directory() async {
    final dir = _dir ??= await _root();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// A file name for [key]: its 64-bit FNV-1a hash. The key itself is kept
  /// inside the file, so a collision reads as a miss, never as another
  /// response.
  static String fileNameFor(String key) {
    // Integers wrap at 64 bits on the VM, which is the arithmetic FNV wants.
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(key)) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return '${hash.toUnsigned(64).toRadixString(16).padLeft(16, '0')}.json';
  }

  Future<File> _file(String key) async =>
      File('${(await _directory()).path}/${fileNameFor(key)}');

  @override
  Future<String?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    final split = text.indexOf('\n');
    if (split < 0 || text.substring(0, split) != key) return null;
    return text.substring(split + 1);
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _file(key);
    // Whole or not at all: a write cut short by the app being killed must
    // not leave half a response to be read next time.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString('$key\n$value', flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clear() async {
    final dir = _dir ?? await _root();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Future<List<StoredItem>> list() async {
    final dir = await _directory();
    final items = <StoredItem>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final stat = await entity.stat();
        final text = await entity.readAsString();
        final split = text.indexOf('\n');
        if (split < 0) {
          await entity.delete();
          continue;
        }
        items.add(StoredItem(
          text.substring(0, split),
          stat.size,
          stat.modified,
          keep: _isKept(text.substring(split + 1)),
        ));
      } catch (e) {
        debugPrint('FileCacheStore: unreadable ${entity.path}: $e');
      }
    }
    return items;
  }
}

/// The platform's encrypted storage -- the Keychain on iOS, the Keystore
/// behind EncryptedSharedPreferences on Android -- for anything personal:
/// tickets, the profile, registrations, certificates, notifications.
///
/// It shares the tokens' container, under its own key prefix ([prefix]),
/// and [clear] deletes only keys with that prefix. A container of its own
/// is not safe on Android: the plugin keeps a custom preferences name or
/// key prefix after the call that set it, so the next token read would
/// have looked in the cache's file and found the person signed out.
/// Entries are kept small and few ([ApiCache]) so the tokens' file stays
/// light.
class SecureCacheStore implements CacheStore {
  SecureCacheStore([SecureStorageService? storage])
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;

  /// Every key here starts with this; nothing else is read or deleted.
  static const prefix = 'saved:';

  @override
  Future<String?> read(String key) => _storage.read(key: '$prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$prefix$key');

  @override
  Future<void> clear() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(prefix)) await _storage.delete(key: key);
    }
  }

  @override
  Future<List<StoredItem>> list() async {
    final all = await _storage.readAll();
    final items = <StoredItem>[];
    for (final entry in all.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      items.add(StoredItem(
        entry.key.substring(prefix.length),
        utf8.encode(entry.value).length,
        _savedAtOf(entry.value) ?? DateTime.fromMillisecondsSinceEpoch(0),
        keep: _isKept(entry.value),
      ));
    }
    return items;
  }

  /// The `saved_at` inside a saved entry, without decoding all of it.
  static DateTime? _savedAtOf(String value) {
    final match = RegExp(r'"saved_at":"([^"]+)"').firstMatch(value);
    return match == null ? null : DateTime.tryParse(match.group(1)!);
  }
}
