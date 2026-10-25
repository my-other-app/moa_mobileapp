import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:finnet/shared/utils/latest_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server whose answers arrive when the test says, query by query.
class _Server {
  final asked = <String>[];
  final _pending = <String, Completer<List<dynamic>>>{};

  Future<List<dynamic>> fetch(String query) {
    asked.add(query);
    return (_pending[query] = Completer<List<dynamic>>()).future;
  }

  void answer(String query, List<dynamic> items) =>
      _pending.remove(query)!.complete(items);

  void refuse(String query, Object error) =>
      _pending.remove(query)!.completeError(error);
}

LatestSearch _search(_Server server) => LatestSearch(
      fetch: server.fetch,
      errorMessage: (e) => 'Search failed: $e',
    );

void main() {
  test('typing sends one request, for the last query, once typing pauses', () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);

      search.update('r');
      time.elapse(const Duration(milliseconds: 100));
      search.update('ro');
      time.elapse(const Duration(milliseconds: 100));
      search.update('robot');
      time.elapse(const Duration(milliseconds: 299));
      expect(server.asked, isEmpty);

      time.elapse(const Duration(milliseconds: 1));
      expect(server.asked, ['robot']);
      expect(search.answer.value.loading, isTrue);

      server.answer('robot', ['Robot Wars']);
      time.flushMicrotasks();
      expect(search.answer.value.answers('robot'), isTrue);
      expect(search.answer.value.items, ['Robot Wars']);
    });
  });

  test("the latest query's answer wins, whatever order the answers arrive in",
      () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);

      search.update('ro');
      time.elapse(searchDebounce);
      search.update('robot');
      time.elapse(searchDebounce);
      expect(server.asked, ['ro', 'robot']);

      server.answer('robot', ['Robot Wars']);
      time.flushMicrotasks();
      // "ro" answers late: it must not replace "robot"'s results.
      server.answer('ro', ['Rowing Club Meetup']);
      time.flushMicrotasks();

      expect(search.answer.value.query, 'robot');
      expect(search.answer.value.items, ['Robot Wars']);
    });
  });

  test('clearing the query drops an answer still on its way', () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);

      search.update('ro');
      time.elapse(searchDebounce);
      search.update('');
      server.answer('ro', ['Rowing Club Meetup']);
      time.flushMicrotasks();

      expect(search.answer.value.answers('ro'), isFalse);
      expect(search.answer.value.items, isEmpty);
      time.elapse(const Duration(seconds: 1));
      expect(server.asked, ['ro']);
    });
  });

  test("submitting sends at once, and an answered query isn't asked again", () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);

      search.submit('robot');
      time.elapse(Duration.zero);
      expect(server.asked, ['robot']);

      // Submitted again while on its way, then once answered: nothing new.
      search.submit('robot');
      server.answer('robot', ['Robot Wars']);
      time.flushMicrotasks();
      search.submit('robot');
      search.update('robot');
      time.elapse(const Duration(seconds: 1));
      expect(server.asked, ['robot']);
    });
  });

  test('submitting while typing pauses sends now, not after the pause', () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);

      search.update('robot');
      time.elapse(const Duration(milliseconds: 50));
      search.submit('robot');
      time.elapse(Duration.zero);
      expect(server.asked, ['robot']);
      time.elapse(const Duration(seconds: 1));
      expect(server.asked, ['robot'], reason: 'the pending one was replaced');
    });
  });

  test('typing back to the answered query asks nothing', () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);
      search.update('robot');
      time.elapse(searchDebounce);
      server.answer('robot', ['Robot Wars']);
      time.flushMicrotasks();

      search.update('robots');
      time.elapse(const Duration(milliseconds: 100));
      search.update('robot');
      time.elapse(const Duration(seconds: 1));

      expect(server.asked, ['robot']);
      expect(search.answer.value.answers('robot'), isTrue);
    });
  });

  test('a failure is put in words, and Retry asks again', () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);
      search.update('robot');
      time.elapse(searchDebounce);
      server.refuse('robot', 'offline');
      time.flushMicrotasks();

      expect(search.answer.value.answers('robot'), isTrue);
      expect(search.answer.value.error, 'Search failed: offline');

      search.retry();
      time.elapse(Duration.zero);
      expect(server.asked, ['robot', 'robot']);
      server.answer('robot', ['Robot Wars']);
      time.flushMicrotasks();
      expect(search.answer.value.error, isNull);
      expect(search.answer.value.items, ['Robot Wars']);
    });
  });

  test('once the search closes, nothing more is sent or shown', () {
    fakeAsync((time) {
      final server = _Server();
      final search = _search(server);

      search.update('ro');
      search.cancel();
      time.elapse(const Duration(seconds: 1));
      expect(server.asked, isEmpty);

      search.submit('robot');
      time.elapse(Duration.zero);
      search.cancel();
      server.answer('robot', ['Robot Wars']);
      time.flushMicrotasks();
      expect(search.answer.value.answers('robot'), isFalse);
    });
  });
}
