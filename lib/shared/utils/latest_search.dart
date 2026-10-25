import 'dart:async';

import 'package:flutter/foundation.dart';

/// How long typing must pause before a search is sent.
const searchDebounce = Duration(milliseconds: 300);

/// What a search shows: the answer for [query], or why there is none.
@immutable
class SearchAnswer {
  const SearchAnswer({
    this.query = '',
    this.items = const [],
    this.error,
    this.loading = false,
  });

  /// The query [items] (or [error]) answer; empty before the first answer.
  final String query;
  final List<dynamic> items;
  final String? error;

  /// A search is on its way to the server.
  final bool loading;

  /// Whether this is the finished answer for [forQuery].
  bool answers(String forQuery) => !loading && query == forQuery;
}

/// Search-as-you-type: one request once typing pauses for [debounce], and
/// only the latest query's answer is shown.
///
/// Sending on every keystroke made a request per letter, and their answers
/// could arrive out of order -- "ro" answering after "robot" put the wrong
/// results under the query. A request still in flight when the query
/// changes is left to finish, and its answer is dropped.
class LatestSearch {
  LatestSearch({
    required this.fetch,
    required this.errorMessage,
    this.debounce = searchDebounce,
  });

  /// The items for a query; throws when the search fails.
  final Future<List<dynamic>> Function(String query) fetch;

  /// The message for a failed search.
  final String Function(Object error) errorMessage;
  final Duration debounce;

  final ValueNotifier<SearchAnswer> answer =
      ValueNotifier(const SearchAnswer());

  Timer? _timer;
  String _wanted = '';

  /// Bumped for every new query: an answer for an older one is dropped.
  int _ticket = 0;

  /// The query as typed. Safe to call from a build: nothing is sent (or
  /// shown) until typing pauses. The same query again changes nothing.
  void update(String query) {
    if (query == _wanted) return;
    _wanted = query;
    _timer?.cancel();
    final ticket = ++_ticket;
    if (query.isEmpty) return;
    // Typed back to what is already answered: nothing to ask.
    final shown = answer.value;
    if (shown.answers(query) && shown.error == null) return;
    _timer = Timer(debounce, () => _run(query, ticket));
  }

  /// The query submitted (the keyboard's search key): sent now, unless it is
  /// already answered or on its way. Safe to call from a build.
  void submit(String query) {
    if (query.isEmpty) return;
    final current = answer.value;
    final settled = query == _wanted &&
        _timer?.isActive != true &&
        (current.loading || (current.query == query && current.error == null));
    if (settled) return;
    _wanted = query;
    _timer?.cancel();
    final ticket = ++_ticket;
    // Not in the build that asked: the answer's listeners rebuild.
    _timer = Timer(Duration.zero, () => _run(query, ticket));
  }

  /// The last query again, after a failure.
  void retry() {
    if (_wanted.isEmpty) return;
    _timer?.cancel();
    final ticket = ++_ticket;
    _timer = Timer(Duration.zero, () => _run(_wanted, ticket));
  }

  /// Nothing more is sent (the search closed).
  void cancel() {
    _timer?.cancel();
    _ticket++;
  }

  Future<void> _run(String query, int ticket) async {
    if (ticket != _ticket) return;
    final shown = answer.value;
    answer.value = SearchAnswer(
      query: shown.query,
      items: shown.items,
      error: shown.error,
      loading: true,
    );
    SearchAnswer result;
    try {
      result = SearchAnswer(query: query, items: await fetch(query));
    } catch (e) {
      result = SearchAnswer(query: query, error: errorMessage(e));
    }
    // A newer query has been typed since: its answer is the one to show.
    if (ticket != _ticket) return;
    answer.value = result;
  }
}
