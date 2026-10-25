import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/volunteer/data/datasources/volunteer_remote_datasource.dart';
import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
