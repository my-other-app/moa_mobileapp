import 'dart:async';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/domain/repositories/volunteer_repository.dart';

/// The volunteer's events, scripted: the events (or a failure), and every
/// call made, in order.
class FakeVolunteerRepository implements VolunteerRepository {
  FakeVolunteerRepository({
    this.events = const [],
    this.failure,
  });

  List<VolunteerEvent> events;
  Failure? failure;

  /// Holds [myEvents] until completed, to see the loading state.
  Completer<void>? hold;

  final calls = <String>[];

  @override
  Future<Result<List<VolunteerEvent>>> myEvents() async {
    calls.add('myEvents');
    if (hold != null) await hold!.future;
    final refused = failure;
    if (refused != null) return Either.left(refused);
    return Either.right(events);
  }
}

VolunteerEvent volunteerEvent({
  int id = 7,
  String name = 'Hack Night 04',
  String club = 'Makers',
  bool hasFee = true,
  int? maxParticipants = 120,
}) =>
    VolunteerEvent(
      id: id,
      slug: 'hack-night-04',
      name: name,
      clubName: club,
      eventDatetime: DateTime(2026, 10, 11, 19, 30),
      hasFee: hasFee,
      regFee: hasFee ? 250 : 0,
      maxParticipants: maxParticipants,
    );

/// No answer at all: no signal at the door.
DioException noSignal(String path) => DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
    );

/// The server refusing, as the app's error interceptor hands it on.
DioException refused(String path, int status, String message,
        {String? code}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.badResponse,
      response: Response(
          requestOptions: RequestOptions(path: path), statusCode: status),
      error: ApiException(
        message: message,
        statusCode: status,
        type: ApiException.typeForStatus(status),
        serverMessage: message,
        errorCode: code,
      ),
    );

GateAttendee guest({
  String id = 'reg-1',
  String name = 'Aarav Menon',
  String ticket = 'MOA-4KD9W-22XQZ',
  DateTime? checkedInAt,
  String? admissionNo,
}) =>
    GateAttendee(
      id: id,
      name: name,
      ticketId: ticket,
      checkedInAt: checkedInAt,
      admissionNo: admissionNo,
    );

GateScanResult scanned(ScanOutcome outcome,
        {GateAttendee? who,
        String? hint,
        String? otherEvent,
        String? byName,
        String? byDoor,
        DateTime? at,
        bool replayed = false}) =>
    GateScanResult(
      outcome: outcome,
      attendee: who,
      hint: hint,
      otherEventName: otherEvent,
      checkedInByName: byName,
      checkedInAtDoor: byDoor,
      checkedInAt: at,
      replayed: replayed,
    );

GateContext gateContext({
  GatePermissions permissions = const GatePermissions(checkIn: true),
  bool hasMerch = false,
  bool hasStore = false,
  int checkedIn = 10,
  String? door,
}) =>
    GateContext(
      eventId: 7,
      eventName: 'Hack Night 04',
      orgName: 'Makers',
      permissions: permissions,
      checkedIn: checkedIn,
      registered: 120,
      doors: [if (door != null) (id: 'd-1', name: door)],
      expectedDoorId: door == null ? null : 'd-1',
      hasMerch: hasMerch,
      hasStore: hasStore,
    );

/// The door console's routes, scripted. Each answer list is used in order,
/// its last answer kept; an answer that is an error is thrown.
class FakeGateApi extends GateApi {
  FakeGateApi({GateContext? context})
      : context_ = context ?? gateContext(),
        super(Dio());

  Object context_;
  final scanAnswers = <Object>[];
  final scans = <QueuedScan>[];
  final batches = <List<QueuedScan>>[];
  Object? batchError;

  /// What the server says of each saved scan, by its code.
  GateScanResult Function(QueuedScan) batchAnswer =
      (s) => scanned(ScanOutcome.checkedIn, who: guest(ticket: s.code));
  final searches = <String>[];
  List<GateAttendee> found = const [];
  final byHand = <(String, String?)>[];
  Object handAnswer = scanned(ScanOutcome.checkedIn, who: guest());
  final merchCalls = <String>[];
  AttendeeMerch merch = const AttendeeMerch(items: []);
  final collects = <(String, String, String?)>[];
  List<StoreOrder> orders = const [];
  final handovers = <String>[];

  T _answer<T>(Object answer) {
    if (answer is T) return answer as T;
    throw answer;
  }

  @override
  Future<GateContext> context(int eventId) async =>
      _answer<GateContext>(context_);

  @override
  Future<GateScanResult> scan(int eventId, QueuedScan scan) async {
    scans.add(scan);
    final answer =
        scanAnswers.length > 1 ? scanAnswers.removeAt(0) : scanAnswers.first;
    return _answer<GateScanResult>(answer);
  }

  @override
  Future<List<ReplayedScan>> scanBatch(
      int eventId, List<QueuedScan> scans) async {
    batches.add(scans);
    final error = batchError;
    if (error != null) throw error;
    return [
      for (final s in scans)
        ReplayedScan(clientRef: s.clientRef, result: batchAnswer(s), scan: s),
    ];
  }

  @override
  Future<List<GateAttendee>> search(int eventId, String query) async {
    searches.add(query);
    return found;
  }

  @override
  Future<GateScanResult> checkInByHand(int eventId, String registrationId,
      {String? door}) async {
    byHand.add((registrationId, door));
    return _answer<GateScanResult>(handAnswer);
  }

  @override
  Future<AttendeeMerch> merchFor(int eventId, String registrationId) async {
    merchCalls.add(registrationId);
    return merch;
  }

  @override
  Future<CollectResult> collect(int eventId,
      {required String itemId,
      required String registrationId,
      String? size,
      String? door}) async {
    collects.add((itemId, registrationId, size));
    return CollectResult(status: 'COLLECTED', collected: true, variantLabel: size);
  }

  @override
  Future<List<StoreOrder>> ordersFor(int eventId, String registrationId) async =>
      orders;

  @override
  Future<StoreOrder?> handOver(int eventId, String orderId) async {
    handovers.add(orderId);
    return null;
  }
}
