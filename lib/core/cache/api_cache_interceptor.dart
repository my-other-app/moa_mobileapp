import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';

/// How a response that came from the saved copy says so, in its `extra`.
enum CachedAnswer {
  /// The server answered 304: the saved copy is current.
  revalidated,

  /// The server could not be reached: the saved copy, of unknown age
  /// (at most [ApiCache.maxAge]).
  offline,
}

/// Saves and revalidates the answers to GETs sent with a [CachePolicy].
///
/// - A saved copy with an `ETag` sends `If-None-Match`; a 304 comes back
///   as a 200 carrying the saved body, marked [CachedAnswer.revalidated].
///   Until the server sends ETags (a backend change in progress), every
///   answer is a full 200 and simply replaces the copy.
/// - A 200 with a JSON body is saved, with its `ETag` and `Last-Modified`.
/// - When the server cannot be reached at all, the saved copy is the
///   answer, marked [CachedAnswer.offline] -- after [RetryInterceptor] has
///   had its one try.
/// - A POST, PUT, PATCH or DELETE, a stream, a request without a policy,
///   and anything [ApiCache.isCacheablePath] refuses pass straight through.
class ApiCacheInterceptor extends Interceptor {
  ApiCacheInterceptor([ApiCache? cache]) : _cache = cache;

  final ApiCache? _cache;
  ApiCache get cache => _cache ?? ApiCache.instance;

  /// Where a response's [CachedAnswer] is, in `response.extra`.
  static const answerKey = 'cachedAnswer';

  static const _entryKey = '_cacheEntry';
  static const _epochKey = '_cacheEpoch';
  static const _keyKey = '_cacheKey';

  /// The [CachedAnswer] a response carries, or null for a fresh one.
  static CachedAnswer? answerOf(Response<dynamic> response) {
    final answer = response.extra[answerKey];
    return answer is CachedAnswer ? answer : null;
  }

  static CachePolicy? _policyFor(RequestOptions options) {
    final policy = CachePolicy.of(options);
    if (policy == null) return null;
    if (options.method.toUpperCase() != 'GET') return null;
    if (options.responseType != ResponseType.json) return null;
    if (!ApiCache.isCacheablePath(options.uri.path)) return null;
    return policy;
  }

  /// A copy written or confirmed less than this long ago is not written
  /// again for the same answer, so the store is not rewritten on every
  /// view. Its week still counts from the last write.
  static const rewriteAfter = Duration(hours: 12);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Whatever happens here, the request goes on: a cache that fails is a
    // cache that missed.
    try {
      await _prepare(options);
    } catch (e) {
      debugPrint('ApiCacheInterceptor: could not prepare ${options.path}: $e');
    }
    handler.next(options);
  }

  Future<void> _prepare(RequestOptions options) async {
    final policy = _policyFor(options);
    if (policy == null) return;
    final key = ApiCache.keyFor(options.uri);
    options.extra[_keyKey] = key;
    options.extra[_epochKey] = cache.epoch;
    final entry = await cache.read(key, policy.scope);
    if (entry == null) return;
    options.extra[_entryKey] = entry;
    final etag = entry.etag;
    if (etag != null) {
      options.headers['If-None-Match'] = etag;
      final validate = options.validateStatus;
      options.validateStatus = (status) => status == 304 || validate(status);
    }
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    var answer = response;
    try {
      answer = await _settle(response);
    } catch (e) {
      debugPrint('ApiCacheInterceptor: could not save '
          '${response.requestOptions.path}: $e');
    }
    handler.next(answer);
  }

  Future<Response<dynamic>> _settle(Response<dynamic> response) async {
    final options = response.requestOptions;
    final policy = _policyFor(options);
    final key = options.extra[_keyKey];
    if (policy == null || key is! String) return response;
    final epoch = options.extra[_epochKey] as int?;
    final saved = options.extra[_entryKey];
    final recent = saved is CacheEntry &&
        cache.now().difference(saved.savedAt) < rewriteAfter;

    if (response.statusCode == 304 && saved is CacheEntry) {
      if (!recent) await cache.confirm(key, policy.scope, saved, epoch: epoch);
      return _fromSaved(options, saved, CachedAnswer.revalidated,
          headers: response.headers);
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status == 200 && (data is Map || data is List)) {
      final etag = response.headers.value('etag');
      final unchanged = recent && saved.etag == etag && _same(saved.data, data);
      if (!unchanged) {
        await cache.write(
          key,
          policy.scope,
          CacheEntry(
            data: data,
            savedAt: cache.now(),
            etag: etag,
            lastModified: response.headers.value('last-modified'),
          ),
          epoch: epoch,
        );
      }
    }
    return response;
  }

  static bool _same(Object? a, Object? b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } catch (_) {
      return false;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final saved = options.extra[_entryKey];
    if (_policyFor(options) != null &&
        saved is CacheEntry &&
        err.response == null &&
        RetryInterceptor.isConnectionFailure(err)) {
      debugPrint('ApiCacheInterceptor: offline, answering ${options.path} '
          'with the copy saved ${saved.savedAt.toLocal()}');
      handler.resolve(_fromSaved(options, saved, CachedAnswer.offline));
      return;
    }
    handler.next(err);
  }

  static Response<dynamic> _fromSaved(
    RequestOptions options,
    CacheEntry saved,
    CachedAnswer answer, {
    Headers? headers,
  }) =>
      Response<dynamic>(
        requestOptions: options,
        data: saved.data,
        statusCode: 200,
        headers: headers,
        extra: {answerKey: answer},
      );
}
