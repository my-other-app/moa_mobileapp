import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/features/clubs/data/datasources/club_remote_datasource.dart';
import 'package:finnet/features/clubs/data/models/club_models.dart';
import 'package:finnet/features/clubs/domain/entities/club_note.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object body = const <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  RequestOptions get only => requests.single;
}

void main() {
  late _RecordingAdapter adapter;
  late ClubRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    dataSource = ClubRemoteDataSourceImpl(dio);
  });

  group('fetching a club\'s notes', () {
    test('calls /clubs/notes/list/{clubId}', () async {
      adapter.body = {'items': []};

      await dataSource.getClubNotes(5);

      expect(adapter.only.path, '/clubs/notes/list/5');
      expect(adapter.only.queryParameters['offset'], 0);
    });

    test('reads the notes out of the paginated envelope', () async {
      adapter.body = {
        'total': 2,
        'items': [
          {
            'id': 1,
            'title': 'Doors open early',
            'note': 'Bring a laptop.',
            'created_at': '2026-10-09T08:00:00+00:00',
          },
          {
            'id': 2,
            'title': 'Limited seats',
            'note': 'Register early.',
            'created_at': '2026-10-08T08:00:00+00:00',
          },
        ],
      };

      final notes = await dataSource.getClubNotes(5);

      expect(notes, hasLength(2));
      expect(notes.first.title, 'Doors open early');
      expect(notes.first.note, 'Bring a laptop.');
    });

    test('a results-shaped body yields nothing, as elsewhere', () async {
      adapter.body = {
        'results': [
          {'id': 1, 'title': 'x', 'note': 'y', 'created_at': '2026-10-09'},
        ],
      };

      expect(await dataSource.getClubNotes(5), isEmpty);
    });
  });

  group('relative time', () {
    ClubNote noteAgo(Duration ago) => ClubNote(
          id: 1,
          title: 't',
          note: 'n',
          createdAt: DateTime.now().subtract(ago),
        );

    test('reads coarsely, which is all a note needs', () {
      expect(noteAgo(const Duration(seconds: 5)).relativeTime, 'just now');
      expect(noteAgo(const Duration(minutes: 1)).relativeTime, '1 minute ago');
      expect(noteAgo(const Duration(minutes: 40)).relativeTime,
          '40 minutes ago');
      expect(noteAgo(const Duration(hours: 1)).relativeTime, '1 hour ago');
      expect(noteAgo(const Duration(hours: 5)).relativeTime, '5 hours ago');
      expect(noteAgo(const Duration(days: 1)).relativeTime, '1 day ago');
      expect(noteAgo(const Duration(days: 3)).relativeTime, '3 days ago');
      expect(noteAgo(const Duration(days: 14)).relativeTime, '2 weeks ago');
      expect(noteAgo(const Duration(days: 400)).relativeTime, '1 year ago');
    });

    test('singular and plural are not mixed up', () {
      // "1 days ago" is the kind of thing that survives to production.
      expect(noteAgo(const Duration(days: 1)).relativeTime, isNot(contains('days')));
      expect(noteAgo(const Duration(hours: 1)).relativeTime, isNot(contains('hours')));
    });
  });

  group('parsing', () {
    test('a missing timestamp does not throw', () {
      // The card shows a relative time; a malformed date must not take the
      // whole tab down with it.
      final note = ClubNote.fromJson(const {
        'id': 1,
        'title': 'Title',
        'note': 'Body',
      });

      expect(note.title, 'Title');
      expect(note.relativeTime, 'just now');
    });
  });

  group('the club logo reaches the card', () {
    test('a club detail response yields a usable thumbnail url', () async {
      // The notes tab had no logo source: callers do not set navigation
      // extras, deep links have none, and NoteListResponse carries no club.
      // Every card fell back to the club's initial. The logo now comes from
      // the club itself, so this pins the shape it arrives in.
      final club = ClubModel.fromJson(const {
        'id': 5,
        'name': 'LetMeGoo',
        'slug': 'letmegoo',
        'logo': {
          'thumbnail': 'https://example.test/logo.thumbnail.png',
          'medium': 'https://example.test/logo.medium.png',
          'large': 'https://example.test/logo.large.png',
          'original': 'https://example.test/logo.png',
        },
      }).toEntity();

      expect(club.logo?.thumbnail, 'https://example.test/logo.thumbnail.png');
    });

    test('a club with no logo yields null rather than throwing', () {
      // Yasya has none in production, so its cards show "Y" -- correct
      // behaviour, not a failure.
      final club = ClubModel.fromJson(const {
        'id': 2,
        'name': 'Yasya',
        'slug': 'yasya',
      }).toEntity();

      expect(club.logo, isNull);
    });
  });
}
