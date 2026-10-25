import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';

/// The door console's routes, for a volunteer signed in to the app: the
/// same ones the club dashboard's door console uses (moa_web
/// `apps/clubs/src/features/gate/api.ts`). The server lets an approved
/// volunteer in by their session and gives them the switches the club set
/// (`app/api/checkins/gate_auth.py`):
///
///   * `GET  /events/{id}/gate/context`              on open
///   * `POST /events/{id}/gate/scan`                 a ticket at the door
///   * `POST /events/{id}/gate/scan-batch`           the offline queue
///   * `GET  /events/{id}/gate/search?q=`            find a guest
///   * `POST /events/{id}/gate/check-in/{reg}`       check in by hand
///   * `GET  /events/{id}/gate/merch/{reg}`          what they are owed
///   * `POST /events/{id}/gate/merch/{item}/collect` hand it over
///   * `GET  /events/{id}/gate/store/{reg}`          their paid orders
///   * `POST /events/{id}/gate/store/{order}/handover`
class GateApi {
  GateApi(this._dio);

  final Dio _dio;

  /// The batch route takes at most this many scans at a time.
  static const batchSize = 200;

  String _gate(int eventId) => '/events/$eventId/gate';

  Map<String, dynamic> _map(Object? data) =>
      jsonObject(data) ?? const <String, dynamic>{};

  /// Saved on the phone (encrypted, as the person's), so a console opened
  /// with no signal still knows the event and the volunteer's door.
  Future<GateContext> context(int eventId) async {
    final r = await _dio.get<dynamic>('${_gate(eventId)}/context',
        options: Options(extra: CachePolicy.personal.extra));
    return GateContext.fromJson(_map(r.data));
  }

  Future<GateScanResult> scan(int eventId, QueuedScan scan) async {
    final r =
        await _dio.post<dynamic>('${_gate(eventId)}/scan', data: scan.toBody());
    return GateScanResult.fromJson(_map(r.data));
  }

  /// The server's answer to each of [scans], with the scan as saved.
  Future<List<ReplayedScan>> scanBatch(
      int eventId, List<QueuedScan> scans) async {
    final r = await _dio.post<dynamic>('${_gate(eventId)}/scan-batch', data: {
      'scans': [for (final s in scans) s.toBody()]
    });
    final saved = {for (final s in scans) s.clientRef: s};
    return [
      for (final row in jsonObjects(_map(r.data)['results']))
        if (jsonString(row['client_ref']) case final ref?)
          ReplayedScan(
            clientRef: ref,
            result: GateScanResult.fromJson(_map(row['response'])),
            scan: saved[ref],
          ),
    ];
  }

  Future<List<GateAttendee>> search(int eventId, String query) async {
    final r = await _dio.get<dynamic>('${_gate(eventId)}/search',
        queryParameters: {'q': query});
    final list = r.data;
    return (list is List ? list : const [])
        .map(GateAttendee.fromJson)
        .whereType<GateAttendee>()
        .toList();
  }

  Future<GateScanResult> checkInByHand(int eventId, String registrationId,
      {String? door}) async {
    final r = await _dio.post<dynamic>(
        '${_gate(eventId)}/check-in/$registrationId',
        data: {'door': door});
    return GateScanResult.fromJson(_map(r.data));
  }

  Future<AttendeeMerch> merchFor(int eventId, String registrationId) async {
    final r =
        await _dio.get<dynamic>('${_gate(eventId)}/merch/$registrationId');
    return AttendeeMerch.fromJson(_map(r.data));
  }

  Future<CollectResult> collect(
    int eventId, {
    required String itemId,
    required String registrationId,
    String? size,
    String? door,
  }) async {
    final r = await _dio.post<dynamic>(
      '${_gate(eventId)}/merch/$itemId/collect',
      data: {
        'registration_id': registrationId,
        if (size != null) 'variant_label': size,
        if (door != null) 'door': door,
      },
    );
    return CollectResult.fromJson(_map(r.data));
  }

  Future<List<StoreOrder>> ordersFor(int eventId, String registrationId) async {
    final r =
        await _dio.get<dynamic>('${_gate(eventId)}/store/$registrationId');
    final list = r.data;
    return (list is List ? list : const [])
        .map(StoreOrder.fromJson)
        .whereType<StoreOrder>()
        .toList();
  }

  Future<StoreOrder?> handOver(int eventId, String orderId) async {
    final r = await _dio.post<dynamic>(
        '${_gate(eventId)}/store/$orderId/handover',
        data: const <String, dynamic>{});
    return StoreOrder.fromJson(r.data);
  }
}

/// No answer came at all -- no signal, or nothing back before the timeout
/// -- as opposed to the server saying no. A scan with no answer is kept on
/// the phone and sent again later; one the server refused is not.
bool gotNoAnswer(Object error) {
  if (error is DioException) {
    if (ApiCacheInterceptor.gotNoAnswer(error)) return true;
    final inner = error.error;
    if (inner is ApiException) return _noAnswer(inner);
    return false;
  }
  return error is ApiException && _noAnswer(error);
}

bool _noAnswer(ApiException e) =>
    e.statusCode == null &&
    (e.type == ApiExceptionType.network || e.type == ApiExceptionType.timeout);

/// What the server said, in its words, for an error it answered; else
/// [fallback].
String gateErrorMessage(Object error, String fallback) {
  final api = error is ApiException
      ? error
      : (error is DioException && error.error is ApiException
          ? error.error as ApiException
          : null);
  final said = api?.serverMessage?.trim();
  if (said != null && said.isNotEmpty) return said;
  if (gotNoAnswer(error)) {
    return "No signal. It wasn't sent; try again when you're back online.";
  }
  return fallback;
}

final gateApiProvider =
    Provider<GateApi>((ref) => GateApi(ref.watch(dioProvider)));
