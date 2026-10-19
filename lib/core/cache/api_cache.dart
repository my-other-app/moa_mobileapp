import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/cache/cache_store.dart';

/// Where a saved response is kept.
enum CacheScope {
  /// The same for everyone (event lists, an event's page, clubs, topics):
  /// plain files in the app's cache directory.
  shared,

  /// About the signed-in person (tickets, registrations, the profile,
  /// certificates, notifications): the platform's encrypted storage.
  personal,
}

/// A GET whose answer may be saved and shown again: from disk at once while
/// the network is asked, and instead of an error when the network cannot
/// be reached. Passed in a request's `extra` ([extra]).
class CachePolicy {
  const CachePolicy({this.scope = CacheScope.shared});

  final CacheScope scope;

  static const shared = CachePolicy();
  static const personal = CachePolicy(scope: CacheScope.personal);

  /// The `extra` that asks for this policy.
  Map<String, dynamic> get extra => {ApiCache.policyKey: this};

  /// The policy [options] asks for, if any.
  static CachePolicy? of(RequestOptions options) {
    final policy = options.extra[ApiCache.policyKey];
    return policy is CachePolicy ? policy : null;
  }
}

/// One saved answer.
class CacheEntry {
  const CacheEntry({
    required this.data,
    required this.savedAt,
    this.etag,
    this.lastModified,
  });

  /// The decoded JSON body.
  final dynamic data;

  /// When the server last confirmed it: written, or answered 304.
  final DateTime savedAt;

  final String? etag;
  final String? lastModified;

  CacheEntry confirmedAt(DateTime at) => CacheEntry(
        data: data,
        savedAt: at,
        etag: etag,
        lastModified: lastModified,
      );

  String encode() => jsonEncode({
        'saved_at': savedAt.toUtc().toIso8601String(),
        if (etag != null) 'etag': etag,
        if (lastModified != null) 'last_modified': lastModified,
        'data': data,
      });

  /// Null for anything unreadable: a saved copy is never worth a crash.
  static CacheEntry? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      final savedAt = DateTime.tryParse('${json['saved_at']}');
      if (savedAt == null) return null;
      final etag = json['etag'];
      final lastModified = json['last_modified'];
      return CacheEntry(
        data: json['data'],
        savedAt: savedAt,
        etag: etag is String && etag.isNotEmpty ? etag : null,
        lastModified:
            lastModified is String && lastModified.isNotEmpty ? lastModified : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Saved API answers: the last copy of each read-mostly screen's data.
///
/// - Only GETs sent with a [CachePolicy] are saved, so nothing is saved by
///   accident; and never one that looks like sign-in, payment or a
///   one-time token ([isCacheablePath]), even if asked.
/// - Each copy is shown for at most [maxAge] after the server last
///   confirmed it, then deleted.
/// - [maxSharedBytes] caps the files, [maxPersonalEntries] and
///   [maxPersonalBytes] the encrypted copies; a single answer larger than
///   [maxEntryBytes] is not saved. [prune] holds them to it, oldest first.
/// - [clear] at sign-out (and sign-in) deletes all of it. A response still
///   in flight when it runs is not saved afterwards ([epoch]).
class ApiCache {
  ApiCache({
    required CacheStore shared,
    required CacheStore personal,
    DateTime Function()? now,
    this.maxAge = const Duration(days: 7),
    this.maxEntryBytes = 256 * 1024,
    this.maxSharedBytes = 20 * 1024 * 1024,
    this.maxPersonalEntries = 40,
    this.maxPersonalBytes = 1024 * 1024,
  })  : _shared = shared,
        _personal = personal,
        _now = now ?? DateTime.now;

  /// The device's stores.
  factory ApiCache.device() =>
      ApiCache(shared: FileCacheStore(), personal: SecureCacheStore());

  static ApiCache? _instance;

  /// The app's one cache, shared by the Dio interceptor and the screens.
  static ApiCache get instance => _instance ??= ApiCache.device();

  @visibleForTesting
  static set instance(ApiCache? cache) => _instance = cache;

  /// The `extra` key a [CachePolicy] travels under.
  static const policyKey = 'apiCache';

  final CacheStore _shared;
  final CacheStore _personal;
  final DateTime Function() _now;

  final Duration maxAge;
  final int maxEntryBytes;
  final int maxSharedBytes;
  final int maxPersonalEntries;
  final int maxPersonalBytes;

  int _epoch = 0;

  /// The cache's clock: when a copy is saved, and how old it is.
  DateTime now() => _now();

  /// Bumped by [clear]. A write carrying an older epoch is dropped: it
  /// belongs to the session that just ended.
  int get epoch => _epoch;

  CacheStore _store(CacheScope scope) =>
      scope == CacheScope.personal ? _personal : _shared;

  /// The key for a GET of [uri]: its path and its query in a fixed order.
  static String keyFor(Uri uri) {
    final params = <String>[];
    uri.queryParametersAll.forEach((name, values) {
      for (final value in values) {
        params.add('${Uri.encodeQueryComponent(name)}='
            '${Uri.encodeQueryComponent(value)}');
      }
    });
    params.sort();
    return params.isEmpty ? 'GET ${uri.path}' : 'GET ${uri.path}?${params.join('&')}';
  }

  /// The key for [path] and [query] sent through [dio], built the way Dio
  /// builds the request's own address, so a screen reading the saved copy
  /// and the interceptor writing it agree.
  static String keyForRequest(
    Dio dio,
    String path, {
    Map<String, dynamic>? query,
  }) {
    final options = Options(method: 'GET').compose(
      dio.options,
      path,
      queryParameters: query,
    );
    return keyFor(options.uri);
  }

  /// Paths never saved, whatever a caller asks: sign-in and its tokens,
  /// payments and checkout, and anything that hands out a one-time token.
  static final _never = RegExp(
    r'/(auth|payments?|checkout|orders?|razorpay|otp|verify|verification)(/|$)|token|password|secret|wallet\.pkpass',
    caseSensitive: false,
  );

  static bool isCacheablePath(String path) => !_never.hasMatch(path);

  /// The saved answer for [key], unless it is older than [maxAge] (then it
  /// is deleted). Null when there is none or it cannot be read.
  Future<CacheEntry?> read(String key, CacheScope scope) async {
    try {
      final store = _store(scope);
      final entry = CacheEntry.decode(await store.read(key));
      if (entry == null) return null;
      if (_now().difference(entry.savedAt) > maxAge) {
        await store.delete(key);
        return null;
      }
      return entry;
    } catch (e) {
      debugPrint('ApiCache: could not read $key: $e');
      return null;
    }
  }

  /// Save [entry] under [key], unless it is too large or [epoch] says the
  /// session it came from has ended.
  Future<void> write(
    String key,
    CacheScope scope,
    CacheEntry entry, {
    int? epoch,
  }) async {
    if (epoch != null && epoch != _epoch) return;
    try {
      final text = entry.encode();
      if (text.length > maxEntryBytes) {
        debugPrint('ApiCache: $key is too large to keep (${text.length} B)');
        await _store(scope).delete(key);
        return;
      }
      // Checked again after the encode: a sign-out may have started.
      if (epoch != null && epoch != _epoch) return;
      await _store(scope).write(key, text);
    } catch (e) {
      debugPrint('ApiCache: could not save $key: $e');
    }
  }

  /// The server said the saved copy for [key] is still current (304).
  Future<void> confirm(
    String key,
    CacheScope scope,
    CacheEntry entry, {
    int? epoch,
  }) =>
      write(key, scope, entry.confirmedAt(_now()), epoch: epoch);

  /// Delete everything saved, both stores.
  Future<void> clear() async {
    _epoch++;
    for (final store in [_shared, _personal]) {
      try {
        await store.clear();
      } catch (e) {
        debugPrint('ApiCache: could not clear a store: $e');
      }
    }
  }

  /// Delete what is too old, then the oldest until each store is within
  /// its caps. Run at start-up; failures are logged and ignored.
  Future<void> prune() async {
    await _prune(_shared, maxBytes: maxSharedBytes);
    await _prune(_personal,
        maxBytes: maxPersonalBytes, maxEntries: maxPersonalEntries);
  }

  Future<void> _prune(
    CacheStore store, {
    required int maxBytes,
    int? maxEntries,
  }) async {
    try {
      final items = await store.list();
      final now = _now();
      final kept = <StoredItem>[];
      for (final item in items) {
        if (now.difference(item.modified) > maxAge) {
          await store.delete(item.key);
        } else {
          kept.add(item);
        }
      }
      kept.sort((a, b) => a.modified.compareTo(b.modified));
      var total = kept.fold<int>(0, (sum, item) => sum + item.bytes);
      var count = kept.length;
      for (final item in kept) {
        final overCount = maxEntries != null && count > maxEntries;
        if (!overCount && total <= maxBytes) break;
        await store.delete(item.key);
        total -= item.bytes;
        count--;
      }
    } catch (e) {
      debugPrint('ApiCache: prune failed: $e');
    }
  }
}

/// The app's [ApiCache], for providers.
final apiCacheProvider = Provider<ApiCache>((ref) => ApiCache.instance);
