import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';

final savedTicketsRepositoryProvider = Provider<SavedTicketsRepository>((ref) {
  return SavedTicketsRepository(
    dio: ref.watch(dioProvider),
    local: ref.watch(savedTicketsLocalDataSourceProvider),
  );
});

/// The person's upcoming and current tickets, kept on the phone.
class SavedTicketsRepository {
  SavedTicketsRepository({
    required Dio dio,
    required SavedTicketsLocalDataSource local,
    DateTime Function()? now,
  })  : _dio = dio,
        _local = local,
        _now = now ?? DateTime.now;

  final Dio _dio;
  final SavedTicketsLocalDataSource _local;
  final DateTime Function() _now;

  /// More than anyone holds tickets for at once; one request.
  static const fetchLimit = 50;

  /// The tickets on the phone whose events are not over, soonest first.
  Future<List<SavedTicket>> saved() async {
    final now = _now();
    final tickets = [
      for (final ticket in await _local.read())
        if (ticket.isCurrentOrUpcoming(now)) ticket,
    ]..sort(_soonestFirst);
    return tickets;
  }

  /// Ask the server for the tickets, and keep exactly what it says.
  ///
  /// The saved list is replaced, not merged: a registration cancelled,
  /// refunded or taken off the list is gone from the server's answer, and
  /// so from the phone. Throws when the server cannot be asked; the saved
  /// list is then left as it was.
  Future<List<SavedTicket>> refresh() async {
    final response = await _dio.get<dynamic>(
      '/events/list',
      queryParameters: {
        'is_registered': true,
        'is_ended': false,
        'offset': 0,
        'limit': fetchLimit,
      },
      // A background refresh: the screens retry their own reads.
      options: Options(extra: {RetryInterceptor.noRetryKey: true}),
    );
    final body = jsonObject(response.data);
    if (body == null || body['items'] is! List) {
      throw const FormatException('The ticket list had no items');
    }
    final now = _now();
    final tickets = [
      for (final item in jsonObjects(body['items']))
        if (SavedTicket.fromRegistration(item) case final ticket?)
          if (ticket.isCurrentOrUpcoming(now)) ticket,
    ]..sort(_soonestFirst);
    await _local.write(tickets);
    return tickets;
  }

  Future<void> clear() => _local.clear();

  static int _soonestFirst(SavedTicket a, SavedTicket b) {
    final at = a.startsAt, bt = b.startsAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  }
}
