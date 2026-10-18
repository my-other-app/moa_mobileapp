import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/payments/domain/entities/payment_order.dart';
import 'package:finnet/features/payments/domain/repositories/payment_repository.dart';
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
/// and nothing reaches secure storage or analytics.
RouteAdapter useFakeApi() {
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
