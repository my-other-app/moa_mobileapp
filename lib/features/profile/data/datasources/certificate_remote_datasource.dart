import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/domain/entities/certificate_style.dart';
import 'package:finnet/features/profile/domain/entities/certificate_verification.dart';

final certificateRemoteDataSourceProvider =
    Provider<CertificateRemoteDataSource>((ref) {
  return CertificateRemoteDataSourceImpl(
    ref.watch(dioProvider),
    cache: ref.watch(apiCacheProvider),
  );
});

abstract class CertificateRemoteDataSource {
  /// Every certificate the user has earned.
  Future<List<Certificate>> getMyCertificates();

  /// The list as last saved on this phone, or null. No network.
  Future<List<Certificate>?> savedCertificates();

  /// How this certificate should look. By its ticket id, signed in: the
  /// server answers only the holder.
  Future<CertificateStyle> getStyle(String ticketId);

  /// `GET /verify/certificates/{code}`: public, no session. [code] is
  /// already in the server's terms ([certificateCodeFrom]): a printed
  /// number or a certificate's public id, never a ticket id.
  Future<CertificateVerification> verify(String code);
}

class CertificateRemoteDataSourceImpl implements CertificateRemoteDataSource {
  final Dio _dio;
  final ApiCache? _cache;

  CertificateRemoteDataSourceImpl(this._dio, {ApiCache? cache})
      : _cache = cache;

  static const _path = '/events/list';

  /// The server's largest page.
  static const pageSize = 100;

  /// Pages read at most: a thousand registrations.
  static const maxPages = 10;

  static Map<String, dynamic> _queryAt(int offset) => <String, dynamic>{
        'is_registered': true,
        'limit': pageSize,
        'offset': offset,
      };

  static final _query = _queryAt(0);

  /// There is no certificates endpoint; a certificate is a registration
  /// the organiser issued one to. So this reads the event list filtered to
  /// the user's own registrations and keeps the ones the server marks
  /// `has_certificate` ([Certificate.fromEventJson]).
  ///
  /// `is_ended` is not sent: a certificate can be issued while the event
  /// is still running, and filtering on it would hide today's until
  /// tomorrow.
  ///
  /// Every page, while the server says there is a next one (up to
  /// [maxPages]): it used to read the first hundred registrations only, so
  /// a frequent attendee's older certificates were missing. The first page
  /// is saved for offline, as before; a later page that fails ends the
  /// list there rather than losing what was read.
  @override
  Future<List<Certificate>> getMyCertificates() async {
    final first = await _dio.get<dynamic>(
      _path,
      queryParameters: _query,
      // The person's own registrations: saved encrypted.
      options: Options(extra: CachePolicy.personalKept.extra),
    );
    final items = [..._itemsOf(first.data)];
    var more = _hasNext(first.data);
    for (var page = 1; more && page < maxPages; page++) {
      try {
        final next = await _dio.get<dynamic>(_path,
            queryParameters: _queryAt(page * pageSize));
        final got = _itemsOf(next.data);
        items.addAll(got);
        more = got.isNotEmpty && _hasNext(next.data);
      } catch (e) {
        debugPrint('Certificates: page ${page + 1} failed: $e');
        break;
      }
    }
    return _certificatesFrom({'items': items});
  }

  static List<Object?> _itemsOf(Object? body) {
    final raw = body is Map ? body['items'] : null;
    return raw is List ? raw : const [];
  }

  static bool _hasNext(Object? body) {
    final next = body is Map ? body['next'] : null;
    return next is String && next.isNotEmpty;
  }

  @override
  Future<List<Certificate>?> savedCertificates() async {
    final data = await (_cache ?? ApiCache.instance).savedAnswer(
      _dio,
      _path,
      query: _query,
      scope: CacheScope.personal,
    );
    return data == null ? null : _certificatesFrom(data);
  }

  static List<Certificate> _certificatesFrom(Object? body) {
    // One certificate a registration, should a page repeat a row (the
    // list moving while it is read).
    final seen = <String>{};
    final certificates = _itemsOf(body)
        .whereType<Map<String, dynamic>>()
        .map(Certificate.fromEventJson)
        .whereType<Certificate>()
        .where((c) => seen.add(c.ticketId))
        .toList();

    // Most recent first: a certificate earned last week is more likely to be
    // the one being looked for than one from two years ago.
    certificates.sort((a, b) => b.issuedOn.compareTo(a.issuedOn));
    return certificates;
  }

  @override
  Future<CertificateVerification> verify(String code) async {
    final response = await _dio.get<dynamic>(
      '/verify/certificates/${Uri.encodeComponent(code)}',
      // Anyone may check a certificate; the answer is never kept.
      options: Options(extra: {'skipAuth': true}),
    );
    final data = response.data;
    return CertificateVerification.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : const {});
  }

  @override
  Future<CertificateStyle> getStyle(String ticketId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/certificates/$ticketId/style',
    );
    return CertificateStyle.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}
