import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/volunteer/data/datasources/volunteer_remote_datasource.dart';
import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart' show RouteAdapter;

class _FakeDataSource implements VolunteerRemoteDataSource {
  Object? throws;
  List<VolunteerEvent> events = const [];
  final List<String> calls = [];

  @override
  Future<List<VolunteerEvent>> myEvents() async {
    calls.add('myEvents');
    if (throws != null) throw throws!;
    return events;
  }
}

void main() {
  late _FakeDataSource dataSource;
  late VolunteerRepositoryImpl repository;

  setUp(() {
    dataSource = _FakeDataSource();
    repository = VolunteerRepositoryImpl(remoteDataSource: dataSource);
  });

  group('myEvents', () {
    test('returns the events on success', () async {
      dataSource.events = [
        VolunteerEvent(
          id: 7,
          slug: 'hack-night-04',
          name: 'Hack Night 04',
          clubName: 'Makers',
          eventDatetime: DateTime(2026, 10, 11, 19, 30),
          hasFee: true,
          regFee: 250,
        ),
      ];

      final result = await repository.myEvents();

      expect(result.isRight, isTrue);
      expect(result.right.single.name, 'Hack Night 04');
    });

    test('maps a boxed ApiException to the right failure', () async {
      // The shape a raw-Dio data source really throws. Before the shared
      // unwrapping mapper this came out as UnknownFailure.
      dataSource.throws = DioException(
        requestOptions: RequestOptions(path: '/events/volunteer/my-events'),
        type: DioExceptionType.badResponse,
        error: const ApiException(
          message: 'Unauthorized. Please log in again.',
          statusCode: 401,
          type: ApiExceptionType.unauthorized,
        ),
      );

      final result = await repository.myEvents();

      expect(result.isLeft, isTrue);
      expect(result.left, isA<AuthFailure>());
    });
  });

  group('the list from the server', () {
    Map<String, dynamic> row(Map<String, dynamic> over) => {
          'id': 7,
          'slug': 'hack-night-04',
          'name': 'Hack Night 04',
          'event_datetime': '2026-11-28T09:00:00+05:30',
          'has_fee': true,
          'reg_fee': 250,
          'club': {'name': 'Makers'},
          ...over,
        };

    test('one odd row costs that row or that field, never the whole list',
        () async {
      final server = RouteAdapter()
        ..on('GET', '/events/volunteer/my-events', [
          row({}),
          // An older event: no slug, a club with no name.
          row({'id': 8, 'slug': null, 'club': {'name': null}}),
          // A draft with no date yet: can't be shown.
          row({'id': 9, 'event_datetime': null}),
          // No id: can't be opened.
          row({'id': null}),
          // An id as text, a fee as text.
          row({'id': '10', 'reg_fee': '99.5', 'has_fee': 'true'}),
          'not an event',
        ]);
      final events =
          await VolunteerRemoteDataSourceImpl(Dio()..httpClientAdapter = server)
              .myEvents();

      expect(events.map((e) => e.id), [7, 8, 10]);
      expect(events[1].slug, '');
      expect(events[1].clubName, '');
      expect(events[2].regFee, 99.5);
      expect(events[2].hasFee, isTrue);
      expect(events.first.eventDatetime.isAtSameMomentAs(
              DateTime.utc(2026, 11, 28, 3, 30)),
          isTrue);
    });

    test('a body that is not a list is no events, not a crash', () async {
      final server = RouteAdapter()
        ..on('GET', '/events/volunteer/my-events', {'detail': 'odd'});
      final events =
          await VolunteerRemoteDataSourceImpl(Dio()..httpClientAdapter = server)
              .myEvents();

      expect(events, isEmpty);
    });
  });
}
