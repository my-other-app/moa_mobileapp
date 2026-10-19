import 'package:dio/dio.dart';
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

  /// How this certificate should look.
  Future<CertificateStyle> getStyle(String ticketId);

  /// `GET /verify/certificates/{code}`: public, no session. [code] is
  /// already in the server's terms ([certificateCodeFrom]).
  Future<CertificateVerification> verify(String code);
}

class CertificateRemoteDataSourceImpl implements CertificateRemoteDataSource {
  final Dio _dio;
  final ApiCache? _cache;

  CertificateRemoteDataSourceImpl(this._dio, {ApiCache? cache})
      : _cache = cache;

  static const _path = '/events/list';
  static const _query = <String, dynamic>{
    'is_registered': true,
    'limit': 100,
    'offset': 0,
  };

  /// There is no certificates endpoint; a certificate is a registration the
  /// user attended. So this reads the event list filtered to the user's own
  /// registrations and keeps the ones with attendance recorded.
  ///
  /// `is_ended` is not sent: an event can be over and attended before its
  /// end time passes -- a volunteer checks people in while it is running --
  /// and filtering on it would hide today's certificate until tomorrow.
  @override
  Future<List<Certificate>> getMyCertificates() async {
    final response = await _dio.get<dynamic>(
      _path,
      queryParameters: _query,
      // The person's own registrations: saved encrypted.
      options: Options(extra: CachePolicy.personal.extra),
    );
    return _certificatesFrom(response.data);
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
    final raw = body is Map ? body['items'] : null;
    final items = raw is List ? raw : const [];
    final certificates = items
        .whereType<Map<String, dynamic>>()
        .map(Certificate.fromEventJson)
        .whereType<Certificate>()
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
