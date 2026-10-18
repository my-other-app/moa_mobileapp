import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/services/push_topics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server's list, as GET /notifications/topics would answer; null is an
/// older server (404), and [error] a failure.
class _Source implements PushTopicSource {
  PushTopicList? list;
  Object? error;
  int fetches = 0;

  @override
  Future<PushTopicList?> fetch() async {
    fetches++;
    if (error != null) throw error!;
    return list;
  }
}

/// FCM's topic calls, recorded; topics in [failing] throw.
class _Messaging implements TopicMessaging {
  final subscribed = <String>[];
  final unsubscribed = <String>[];
  final failing = <String>{};

  @override
  Future<void> subscribe(String topic) async {
    if (failing.contains(topic)) throw Exception('FCM said no to $topic');
    subscribed.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (failing.contains(topic)) throw Exception('FCM said no to $topic');
    unsubscribed.add(topic);
  }

  void reset() {
    subscribed.clear();
    unsubscribed.clear();
  }
}

class _Store implements AppliedTopicsStore {
  AppliedTopics? value;

  @override
  Future<AppliedTopics?> read() async => value;

  @override
  Future<void> write(AppliedTopics applied) async => value = applied;

  @override
  Future<void> clear() async => value = null;
}

PushTopicList _list(List<String> topics, String version) =>
    PushTopicList(topics: topics, version: version);

void main() {
  late _Source source;
  late _Messaging messaging;
  late _Store store;
  late TopicReconciler reconciler;

  setUp(() {
    source = _Source();
    messaging = _Messaging();
    store = _Store();
    reconciler =
        TopicReconciler(source: source, messaging: messaging, store: store);
  });

  group('TopicReconciler', () {
    test('the first reconcile subscribes to every topic on the list', () async {
      source.list = _list(['all', 'club_12', 'topic_robotics'], 'v1');

      expect(await reconciler.reconcile('tok-1'), TopicSync.applied);

      expect(messaging.subscribed,
          unorderedEquals(['all', 'club_12', 'topic_robotics']));
      expect(messaging.unsubscribed, isEmpty);
      expect(store.value!.version, 'v1');
      expect(await reconciler.readyFor('tok-1'), isTrue);
      expect(await reconciler.readyFor('tok-2'), isFalse);
      expect(await reconciler.readyFor(null), isFalse);
    });

    test('the same version again costs no FCM call', () async {
      source.list = _list(['all', 'club_12'], 'v1');
      await reconciler.reconcile('tok-1');
      messaging.reset();

      expect(await reconciler.reconcile('tok-1'), TopicSync.upToDate);

      expect(messaging.subscribed, isEmpty);
      expect(messaging.unsubscribed, isEmpty);
    });

    test('an unfollow, a follow: only the difference is called', () async {
      source.list = _list(['all', 'club_12', 'topic_robotics'], 'v1');
      await reconciler.reconcile('tok-1');
      messaging.reset();
      // Unfollowed club 12, followed club 40 (or muted 12: the same to the app).
      source.list = _list(['all', 'club_40', 'topic_robotics'], 'v2');

      expect(await reconciler.reconcile('tok-1'), TopicSync.applied);

      expect(messaging.unsubscribed, ['club_12']);
      expect(messaging.subscribed, ['club_40']);
      expect(store.value!.topics, {'all', 'club_40', 'topic_robotics'});
      expect(store.value!.version, 'v2');
    });

    test('interests changed: the topics that left are left', () async {
      source.list = _list(['all', 'topic_art', 'topic_robotics'], 'v1');
      await reconciler.reconcile('tok-1');
      messaging.reset();
      source.list = _list(['all', 'topic_music'], 'v2');

      await reconciler.reconcile('tok-1');

      expect(messaging.unsubscribed,
          unorderedEquals(['topic_art', 'topic_robotics']));
      expect(messaging.subscribed, ['topic_music']);
    });

    test('a server without the endpoint: nothing is done', () async {
      source.list = null;

      expect(await reconciler.reconcile('tok-1'), TopicSync.unsupported);

      expect(messaging.subscribed, isEmpty);
      expect(messaging.unsubscribed, isEmpty);
      expect(store.value, isNull);
      expect(await reconciler.readyFor('tok-1'), isFalse);
    });

    test('a list that cannot be fetched changes nothing', () async {
      source.list = _list(['all'], 'v1');
      await reconciler.reconcile('tok-1');
      messaging.reset();
      source.error = Exception('offline');

      expect(await reconciler.reconcile('tok-1'), TopicSync.failed);

      expect(messaging.subscribed, isEmpty);
      expect(await reconciler.readyFor('tok-1'), isTrue);
    });

    test(
        'what FCM refused is tried again, and the device is not ready until then',
        () async {
      source.list = _list(['all', 'club_12', 'club_40'], 'v1');
      messaging.failing.add('club_40');

      expect(await reconciler.reconcile('tok-1'), TopicSync.partial);

      expect(store.value!.topics, {'all', 'club_12'});
      expect(store.value!.version, isNull);
      expect(await reconciler.readyFor('tok-1'), isFalse);

      messaging
        ..failing.clear()
        ..reset();
      expect(await reconciler.reconcile('tok-1'), TopicSync.applied);
      expect(messaging.subscribed, ['club_40']);
      expect(await reconciler.readyFor('tok-1'), isTrue);
    });

    test('a new push token starts in no topic', () async {
      source.list = _list(['all', 'club_12'], 'v1');
      await reconciler.reconcile('tok-1');
      messaging.reset();

      expect(await reconciler.reconcile('tok-2'), TopicSync.applied);

      expect(messaging.subscribed, unorderedEquals(['all', 'club_12']));
      expect(await reconciler.readyFor('tok-2'), isTrue);
      expect(await reconciler.readyFor('tok-1'), isFalse);
    });

    test('signing out leaves every topic and forgets them', () async {
      source.list = _list(['all', 'club_12', 'topic_robotics'], 'v1');
      await reconciler.reconcile('tok-1');
      messaging.reset();

      await reconciler.clear();

      expect(messaging.unsubscribed,
          unorderedEquals(['all', 'club_12', 'topic_robotics']));
      expect(store.value, isNull);
      expect(await reconciler.readyFor('tok-1'), isFalse);
    });

    test(
        'a topic that could not be left is left by the next person on the device',
        () async {
      source.list = _list(['all', 'club_12'], 'v1');
      await reconciler.reconcile('tok-1');
      messaging
        ..reset()
        ..failing.add('club_12');

      await reconciler.clear();

      expect(store.value!.topics, {'club_12'});
      expect(store.value!.version, isNull);

      // Someone else signs in on the same token: club 12 is not theirs.
      messaging
        ..failing.clear()
        ..reset();
      source.list = _list(['all', 'club_99'], 'v7');
      await reconciler.reconcile('tok-1');

      expect(messaging.unsubscribed, ['club_12']);
      expect(messaging.subscribed, unorderedEquals(['all', 'club_99']));
    });

    test('two reconciles at once run one after the other', () async {
      source.list = _list(['all', 'club_12'], 'v1');

      final results = await Future.wait([
        reconciler.reconcile('tok-1'),
        reconciler.reconcile('tok-1'),
      ]);

      expect(results, [TopicSync.applied, TopicSync.upToDate]);
      expect(messaging.subscribed, unorderedEquals(['all', 'club_12']));
    });
  });

  group('AppliedTopics', () {
    test('round-trips as JSON, and anything else reads as nothing', () {
      const applied =
          AppliedTopics(token: 't', topics: {'b', 'a'}, version: 'v');
      final back = AppliedTopics.fromJson(applied.toJson())!;
      expect(back.token, 't');
      expect(back.topics, {'a', 'b'});
      expect(back.version, 'v');
      expect(AppliedTopics.fromJson('nonsense'), isNull);
      expect(AppliedTopics.fromJson({'token': 1}), isNull);
    });
  });

  group('DioPushTopicSource', () {
    test('GET /notifications/topics', () async {
      final s =
          _server(200, '{"topics": ["all", "club_12"], "version": "abc"}');

      final list = await DioPushTopicSource(s.dio).fetch();

      expect(s.adapter.requests.single.method, 'GET');
      expect(s.adapter.requests.single.uri.toString(),
          'https://example.test/api/v1/notifications/topics');
      expect(list!.topics, ['all', 'club_12']);
      expect(list.version, 'abc');
    });

    for (final status in [404, 405]) {
      test('a server without the endpoint ($status) has no list', () async {
        expect(
            await DioPushTopicSource(_server(status, '{"message":"x"}').dio)
                .fetch(),
            isNull);
      });
    }

    test(
        'a reconcile against a server without the endpoint calls FCM for nothing',
        () async {
      final messaging = _Messaging();
      final store = _Store();
      final r = TopicReconciler(
        source: DioPushTopicSource(_server(404, '{"message":"Not Found"}').dio),
        messaging: messaging,
        store: store,
      );

      expect(await r.reconcile('tok-1'), TopicSync.unsupported);
      expect(messaging.subscribed, isEmpty);
      expect(messaging.unsubscribed, isEmpty);
      expect(store.value, isNull);
    });

    test('any other failure is a failure, not an empty list', () async {
      await expectLater(
          DioPushTopicSource(_server(500, '{"message":"x"}').dio).fetch(),
          throwsA(anything));
    });
  });
}

class _Answer implements HttpClientAdapter {
  _Answer(this.status, this.body);

  final int status;
  final String body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _Answer adapter}) _server(int status, String body) {
  final adapter = _Answer(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
    ..httpClientAdapter = adapter
    ..interceptors.add(ErrorInterceptor());
  return (dio: dio, adapter: adapter);
}
