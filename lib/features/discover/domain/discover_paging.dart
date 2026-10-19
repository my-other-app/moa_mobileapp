import 'package:equatable/equatable.dart';

/// The deepest offset `/discover/events`, `/calendar` and `/clubs` serve:
/// past it the server answers 422. Deeper pages go by cursor (`after`).
const discoverMaxOffset = 1000;

/// Rows a list asks for at a time (the server's limit is 60).
const discoverPageSize = 20;

/// Where a page starts: an offset, or the cursor the page before it ended
/// on (`next_cursor`, sent back as `after`). With a cursor, no offset goes:
/// the server ignores it then anyway.
class PageRequest extends Equatable {
  const PageRequest.first({this.limit = discoverPageSize})
      : offset = 0,
        after = null;

  const PageRequest.after(String this.after, {this.limit = discoverPageSize})
      : offset = 0;

  const PageRequest.offset(this.offset, {this.limit = discoverPageSize})
      : after = null;

  final int offset;
  final String? after;
  final int limit;

  bool get isFirst => after == null && offset == 0;

  /// The paging part of a query.
  Map<String, dynamic> get query => after != null
      ? {'after': after, 'limit': limit}
      : {'offset': offset, 'limit': limit};

  @override
  List<Object?> get props => [offset, after, limit];
}

/// A page of one of the discover lists.
///
/// [cursored]: the server pages by cursor (it sent `next_cursor`, even
/// null); [cursor] is where the next page starts, null on the last.
/// [capped]: the server stopped counting at 1,000 (`total_capped`), so
/// [total] is a floor and the pages go on.
class DiscoverPage<T> extends Equatable {
  const DiscoverPage({
    this.items = const [],
    this.total = 0,
    this.capped = false,
    this.offset = 0,
    this.limit = discoverPageSize,
    this.cursored = false,
    this.cursor,
  });

  final List<T> items;
  final int total;
  final bool capped;
  final int offset;
  final int limit;
  final bool cursored;
  final String? cursor;

  @override
  List<Object?> get props =>
      [items, total, capped, offset, limit, cursored, cursor];
}

/// Where the page after [page] starts, given [read] rows read so far; null
/// when there is no more:
///
/// * the server said where (`next_cursor`): after it; a null cursor ends it;
/// * a server without cursors: by offset, while the offset is one it
///   serves ([max], 1,000 -- never past it, which is a 422);
/// * an empty page ends the list whatever the total said.
PageRequest? nextPageAfter(
  DiscoverPage<Object?> page,
  int read, {
  int max = discoverMaxOffset,
  int limit = discoverPageSize,
}) {
  if (page.items.isEmpty) return null;
  if (page.cursored) {
    final cursor = page.cursor;
    return cursor == null ? null : PageRequest.after(cursor, limit: limit);
  }
  // Without cursors: a short page is the end, unless the total was capped.
  final more = page.capped || read < page.total;
  if (!more || read > max) return null;
  return PageRequest.offset(read, limit: limit);
}
