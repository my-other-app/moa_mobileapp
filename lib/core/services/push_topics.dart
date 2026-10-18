import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/core/utils/error_utils.dart';

/// The FCM topics this device subscribes to for its person, so a broadcast
/// -- a club's new post or event, a new event in one of their topics, an
/// announcement to everyone -- reaches it in one send from the server
/// instead of one per device.
///
/// The server keeps the truth (`GET /notifications/topics`: `club_{id}` for
/// each club followed and not muted, `topic_{slug}` for the topics of their
/// interests, `all`, each unless switched off) with a version that changes
/// exactly when the list does. [TopicReconciler] fetches it, subscribes to
/// what is new, unsubscribes from what left, and keeps what it applied, so an
/// unchanged list costs no FCM call. A server without the endpoint (404) is
/// left alone: nothing is subscribed and nothing changes.
@immutable
class PushTopicList {
  const PushTopicList({required this.topics, required this.version});

  final List<String> topics;
  final String version;

  /// The server's answer, or null for one that is not a list.
  static PushTopicList? fromJson(Object? json) {
    if (json is! Map) return null;
    final topics = json['topics'];
    final version = json['version'];
    if (topics is! List || version is! String || version.isEmpty) return null;
    return PushTopicList(
      topics: [
        for (final t in topics)
          if (t is String && t.isNotEmpty) t,
      ],
      version: version,
    );
  }
}

/// Where the list comes from.
abstract class PushTopicSource {
  /// The list, or null when the server has none to give (an older server
  /// answers 404 or 405). Throws for any other failure.
  Future<PushTopicList?> fetch();
}

/// `GET /notifications/topics`.
class DioPushTopicSource implements PushTopicSource {
  DioPushTopicSource(this._dio);

  final Dio _dio;

  @override
  Future<PushTopicList?> fetch() async {
    try {
      final response = await _dio.get<dynamic>('/notifications/topics');
      return PushTopicList.fromJson(response.data);
    } catch (e) {
      final status = statusCodeOf(e) ??
          (e is DioException ? e.response?.statusCode : null);
      if (status == 404 || status == 405) return null;
      rethrow;
    }
  }
}

/// FCM's topic calls, so the reconcile can be tested without Firebase.
abstract class TopicMessaging {
  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);
}

/// [TopicMessaging] through `FirebaseMessaging`. On iOS a topic call needs
/// the APNs token first: the caller only reconciles once it has the FCM
/// token, which itself waits for the APNs one.
class FirebaseTopicMessaging implements TopicMessaging {
  FirebaseTopicMessaging(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribe(String topic) =>
      _messaging.unsubscribeFromTopic(topic);
}

/// What this install last applied: for which push token, which topics, and
/// the server's version of the list -- null when the last reconcile left
/// part of it undone, so the next one tries again.
@immutable
class AppliedTopics {
  const AppliedTopics({
    required this.token,
    required this.topics,
    required this.version,
  });

  final String token;
  final Set<String> topics;
  final String? version;

  Map<String, dynamic> toJson() => {
        'token': token,
        'topics': topics.toList()..sort(),
        'version': version,
      };

  static AppliedTopics? fromJson(Object? json) {
    if (json is! Map) return null;
    final token = json['token'];
    final topics = json['topics'];
    if (token is! String || topics is! List) return null;
    final version = json['version'];
    return AppliedTopics(
      token: token,
      topics: {
        for (final t in topics)
          if (t is String) t,
      },
      version: version is String ? version : null,
    );
  }
}

/// Where [AppliedTopics] is kept between launches.
abstract class AppliedTopicsStore {
  Future<AppliedTopics?> read();
  Future<void> write(AppliedTopics applied);
  Future<void> clear();
}

/// [AppliedTopicsStore] in the app's secure storage, as JSON under one key.
class SecureAppliedTopicsStore implements AppliedTopicsStore {
  SecureAppliedTopicsStore(this._storage);

  static const key = 'push_topics_applied';

  final SecureStorageService _storage;

  @override
  Future<AppliedTopics?> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppliedTopics.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AppliedTopics applied) =>
      _storage.write(key: key, value: jsonEncode(applied.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: key);
}

/// What a reconcile did.
enum TopicSync {
  /// The server has no topic list (an older server): nothing was done.
  unsupported,

  /// The list was fetched and is the one already applied: no FCM call.
  upToDate,

  /// The device is now in exactly the list's topics.
  applied,

  /// Some FCM calls failed; the next reconcile tries the rest.
  partial,

  /// The list could not be fetched (offline, a server error).
  failed,
}

/// Keeps this device's FCM topics equal to the server's list for its person.
class TopicReconciler {
  TopicReconciler({
    required this.source,
    required this.messaging,
    required this.store,
    this.concurrency = 4,
  });

  final PushTopicSource source;
  final TopicMessaging messaging;
  final AppliedTopicsStore store;

  /// FCM calls in flight at once: a first reconcile for someone following
  /// two hundred clubs is two hundred calls.
  final int concurrency;

  Future<void>? _running;

  /// Bring the device's topics for push token [token] in line with the
  /// server's list. One at a time: a second call while one runs waits for
  /// it and then runs, so the last change is always applied.
  Future<TopicSync> reconcile(String token) async {
    while (_running != null) {
      await _running;
    }
    final done = Completer<void>();
    _running = done.future;
    try {
      return await _reconcile(token);
    } finally {
      _running = null;
      done.complete();
    }
  }

  Future<TopicSync> _reconcile(String token) async {
    final PushTopicList? list;
    try {
      list = await source.fetch();
    } catch (e) {
      debugPrint('TopicReconciler: could not fetch the topic list: $e');
      return TopicSync.failed;
    }
    if (list == null) return TopicSync.unsupported;

    final applied = await _read();
    // Topics belong to the push token: a new token starts in none (and the
    // old one is gone with its subscriptions).
    final sameToken = applied != null && applied.token == token;
    if (sameToken && applied.version == list.version) return TopicSync.upToDate;
    final have = sameToken ? {...applied.topics} : <String>{};
    final want = list.topics.toSet();

    final left = await _each(have.difference(want), messaging.unsubscribe);
    final joined = await _each(want.difference(have), messaging.subscribe);
    final now = {...have}
      ..removeAll(left.done)
      ..addAll(joined.done);
    final complete = left.failed == 0 && joined.failed == 0;
    await _write(AppliedTopics(
      token: token,
      topics: now,
      version: complete ? list.version : null,
    ));
    return complete ? TopicSync.applied : TopicSync.partial;
  }

  /// Signing out: leave every topic this device is in for its person. What
  /// could not be left is remembered, so the next person's reconcile on the
  /// same token takes it out.
  Future<void> clear() async {
    while (_running != null) {
      await _running;
    }
    final applied = await _read();
    if (applied == null) return;
    final left = await _each(applied.topics, messaging.unsubscribe);
    if (left.failed == 0) {
      await _guard(store.clear);
    } else {
      await _write(AppliedTopics(
        token: applied.token,
        topics: applied.topics.difference(left.done.toSet()),
        version: null,
      ));
    }
  }

  /// Whether this device is in every topic of its person's list for push
  /// token [token]: what it reports with the token as `topics: 1`, so the
  /// server stops sending it broadcasts one by one only once it is.
  Future<bool> readyFor(String? token) async {
    if (token == null) return false;
    final applied = await _read();
    return applied != null && applied.token == token && applied.version != null;
  }

  Future<({List<String> done, int failed})> _each(
    Set<String> topics,
    Future<void> Function(String topic) call,
  ) async {
    final done = <String>[];
    var failed = 0;
    final queue = topics.toList()..sort();
    for (var i = 0; i < queue.length; i += concurrency) {
      final batch = queue.skip(i).take(concurrency);
      await Future.wait(batch.map((topic) async {
        try {
          await call(topic);
          done.add(topic);
        } catch (e) {
          failed++;
          debugPrint('TopicReconciler: $topic: $e');
        }
      }));
    }
    return (done: done, failed: failed);
  }

  Future<AppliedTopics?> _read() async {
    try {
      return await store.read();
    } catch (e) {
      debugPrint('TopicReconciler: could not read the applied topics: $e');
      return null;
    }
  }

  Future<void> _write(AppliedTopics applied) =>
      _guard(() => store.write(applied));

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      debugPrint('TopicReconciler: could not keep the applied topics: $e');
    }
  }
}
