import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/payments/domain/entities/payment_order.dart';
import 'package:finnet/features/payments/domain/repositories/payment_repository.dart';
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';

/// Answers requests by method and path, in the order they were queued; the
/// last answer for a route keeps being given. Anything unrouted is a 404.
class RouteAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, List<(int, Object?)>> _routes = {};
  final Map<String, Stream<Uint8List> Function()> _streams = {};

  void on(String method, String path, Object? body, {int status = 200}) {
    _routes.putIfAbsent('$method $path', () => []).add((status, body));
  }

  /// GET [path] answers `text/event-stream`, with a body from [open] for
  /// each connection.
  void stream(String path, Stream<Uint8List> Function() open) {
    _streams['GET $path'] = open;
  }

  List<RequestOptions> sent(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final stream = _streams['${options.method} ${options.path}'];
    if (stream != null) {
      return ResponseBody(stream(), 200, headers: {
        Headers.contentTypeHeader: ['text/event-stream; charset=utf-8'],
      });
    }
    final queue = _routes['${options.method} ${options.path}'];
    final (status, body) = queue == null
        ? (404, <String, dynamic>{'message': 'Not found'})
        : (queue.length > 1 ? queue.removeAt(0) : queue.first);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Points the app's one Dio (`APIService.instance`) at [adapter], with only
/// the app's error interceptor -- failures arrive shaped as in production,
/// and nothing reaches secure storage or analytics. The saved-answer cache
/// starts empty, in memory.
RouteAdapter useFakeApi({ApiCache? cache}) {
  ApiCache.instance = cache ??
      ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
  TicketImages.instance = MemoryTicketImages();
  CertificateDocuments.instance = MemoryCertificateDocuments();
  final adapter = RouteAdapter();
  APIService.instance.dio
    ..httpClientAdapter = adapter
    ..interceptors.clear()
    ..interceptors.add(ErrorInterceptor());
  return adapter;
}

const testProfile = UserProfile(
  id: 'u-1',
  fullName: 'Asha Menon',
  email: 'asha@example.com',
  phone: '9876543210',
);

class FakeProfileRepository implements ProfileRepository {
  UserProfile profile = testProfile;

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(profile);

  @override
  Future<Result<List<Organization>>> getOrganizations() async =>
      Either.right(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class FakePaymentRepository implements PaymentRepository {
  Result<PaymentOrder> order = Either.right(const PaymentOrder(
    id: 'o-1',
    razorpayOrderId: 'order_1',
    amount: 250,
  ));
  final List<(int, String)> orders = [];

  @override
  Future<Result<PaymentOrder>> createRegistrationOrder({
    required int eventId,
    required String registrationId,
  }) async {
    orders.add((eventId, registrationId));
    return order;
  }

  @override
  Future<Result<void>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
  }) async =>
      Either.right(null);
}

/// The tickets' designs kept in memory, fetched through the app's Dio (the
/// fake API): a widget test's clock is fake, and the disk the real ones
/// live on never answers it.
class MemoryTicketImages extends TicketImages {
  final kept = <String, Uint8List>{};

  @override
  Future<Uint8List?> saved(String code) async => kept[code];

  @override
  Future<({Uint8List bytes, bool current})> fetch(String code) async {
    try {
      final response = await APIService.instance.dio.get<List<int>>(
        TicketImages.pathFor(code),
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      if (bytes.isEmpty) {
        throw const FormatException('The document came back empty');
      }
      kept[code] = bytes;
      return (bytes: bytes, current: true);
    } on DioException catch (e) {
      final saved = kept[code];
      if (saved != null && ApiCacheInterceptor.gotNoAnswer(e)) {
        return (bytes: saved, current: false);
      }
      rethrow;
    }
  }

  /// The PDFs a screen asked to keep: none is fetched here.
  final pdfsKept = <String>[];

  @override
  Future<void> keepPdf(String code, {DateTime? now}) async =>
      pdfsKept.add(code);

  @override
  Future<void> forget(String code) async => kept.remove(code);
}

/// The certificates' renders kept in memory, fetched through the app's Dio
/// (the fake API), for the same reason as [MemoryTicketImages].
class MemoryCertificateDocuments extends CertificateDocuments {
  final kept = <String, Uint8List>{};
  final pdfsKept = <String>[];

  @override
  Future<Uint8List?> savedImage(String ticketId) async => kept[ticketId];

  @override
  Future<({Uint8List bytes, bool current})> fetchImage(String ticketId) async {
    try {
      final response = await APIService.instance.dio.get<List<int>>(
        CertificateDocuments.imagePathFor(ticketId),
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      if (bytes.isEmpty) {
        throw const FormatException('The document came back empty');
      }
      kept[ticketId] = bytes;
      return (bytes: bytes, current: true);
    } on DioException catch (e) {
      final saved = kept[ticketId];
      if (saved != null && ApiCacheInterceptor.gotNoAnswer(e)) {
        return (bytes: saved, current: false);
      }
      rethrow;
    }
  }

  /// The PDFs on the phone, by certificate; none unless a test puts one.
  final pdfs = <String, SavedDocument>{};

  @override
  Future<SavedDocument> pdf(String ticketId) async =>
      pdfs[ticketId] ??
      (throw FileSystemException('No PDF kept in this test', ticketId));

  @override
  Future<void> keepPdf(String ticketId, {DateTime? now}) async =>
      pdfsKept.add(ticketId);

  @override
  Future<void> forget(String ticketId) async => kept.remove(ticketId);
}
