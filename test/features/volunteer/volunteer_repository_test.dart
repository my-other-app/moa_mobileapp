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
  Map<String, dynamic> validateBody = const {};
  final List<String> calls = [];

  @override
  Future<List<VolunteerEvent>> myEvents() async {
    calls.add('myEvents');
    if (throws != null) throw throws!;
    return events;
  }

  @override
  Future<Map<String, dynamic>> validate(int eventId, String ticketId) async {
    calls.add('validate($eventId,$ticketId)');
    if (throws != null) throw throws!;
    return validateBody;
  }

  @override
  Future<void> checkin(int eventId, String ticketId) async {
    calls.add('checkin($eventId,$ticketId)');
    if (throws != null) throw throws!;
  }
}

/// The body `validate_ticket` returns on a good ticket, field for field.
Map<String, dynamic> _validBody({String? location}) => {
      'valid': true,
      'ticket_id': 'MOA-4KD9W-22XQZ',
      'ticket_holder_name': 'Aarav Menon',
      'ticket_holder_email': 'aarav@example.com',
      'event_name': 'Hack Night 04',
      'event_datetime': '2026-10-11T19:30:00+00:00',
      'location': location,
      'is_paid': true,
      'has_fee': true,
    };

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

  group('validate', () {
    test('reads the holder details off a valid ticket', () async {
      dataSource.validateBody = _validBody(location: 'Lab 2, Block C');

      final result = await repository.validate(7, 'moa-4kd9w-22xqz');

      expect(result.success, isTrue);
      expect(result.type, CheckinResultType.success);
      expect(result.ticketHolderName, 'Aarav Menon');
      expect(result.ticketHolderEmail, 'aarav@example.com');
      expect(result.location, 'Lab 2, Block C');
      // The server matches case-insensitively and echoes the canonical
      // spelling, so its id is kept rather than the scanned one.
      expect(result.ticketId, 'MOA-4KD9W-22XQZ');
      expect(result.eventTime, '19:30');
    });

    test('a 200 that says valid:false does not open the door', () async {
      // Nothing sends this today -- the server answers non-2xx for every
      // refusal. If that ever changes, a success built from the status code
      // alone would admit someone on a refusal.
      dataSource.validateBody = const {
        'valid': false,
        'message': 'User already checked-in',
      };

      final result = await repository.validate(7, 'MOA-1');

      expect(result.success, isFalse);
      expect(result.type, CheckinResultType.alreadyScanned);
    });

    test('a missing event_datetime leaves the time blank, not wrong', () async {
      final body = _validBody()..remove('event_datetime');
      dataSource.validateBody = body;

      final result = await repository.validate(7, 'MOA-1');

      expect(result.success, isTrue);
      expect(result.eventDate, isNull);
      expect(result.eventTime, isNull);
    });

    test('a refusal comes back classified, not thrown', () async {
      dataSource.throws = DioException(
        requestOptions: RequestOptions(path: '/events/volunteer/validate/7'),
        type: DioExceptionType.badResponse,
        error: const ApiException(
          message: 'User already checked-in',
          statusCode: 400,
          type: ApiExceptionType.badRequest,
          serverMessage: 'User already checked-in',
        ),
      );

      final result = await repository.validate(7, 'MOA-1');

      expect(result.success, isFalse);
      expect(result.type, CheckinResultType.alreadyScanned);
    });
  });

  group('checkin', () {
    test('succeeds and carries the ticket id back', () async {
      final result = await repository.checkin(7, 'MOA-1');

      expect(result.success, isTrue);
      expect(result.ticketId, 'MOA-1');
      expect(dataSource.calls.single, 'checkin(7,MOA-1)');
    });

    test('a second check-in of the same ticket is reported as already used',
        () async {
      // checkin is not idempotent: the endpoint sets is_attended, so a
      // double-tap must read as "already in", never as a fresh admission.
      dataSource.throws = const ApiException(
        message: 'User already checked-in',
        statusCode: 400,
        type: ApiExceptionType.badRequest,
        serverMessage: 'User already checked-in',
      );

      final result = await repository.checkin(7, 'MOA-1');

      expect(result.success, isFalse);
      expect(result.type, CheckinResultType.alreadyScanned);
    });

    test('a dropped connection during check-in is not a successful entry',
        () async {
      // The dangerous direction: the server may well have recorded the
      // check-in. Reporting unreachable sends the volunteer to scan again,
      // which then answers "already checked-in" -- the right outcome.
      dataSource.throws = const ApiException(
        message: 'No internet connection.',
        type: ApiExceptionType.network,
      );

      final result = await repository.checkin(7, 'MOA-1');

      expect(result.success, isFalse);
      expect(result.type, CheckinResultType.unreachable);
    });
  });
}
