import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/domain/entities/certificate_style.dart';

final certificateRemoteDataSourceProvider =
    Provider<CertificateRemoteDataSource>((ref) {
  return CertificateRemoteDataSourceImpl(ref.watch(dioProvider));
});

abstract class CertificateRemoteDataSource {
  /// Every certificate the user has earned.
  Future<List<Certificate>> getMyCertificates();

  /// How this certificate should look.
  Future<CertificateStyle> getStyle(String ticketId);
}

class CertificateRemoteDataSourceImpl implements CertificateRemoteDataSource {
  final Dio _dio;

  CertificateRemoteDataSourceImpl(this._dio);

  /// There is no certificates endpoint; a certificate is a registration the
  /// user attended. So this reads the event list filtered to the user's own
  /// registrations and keeps the ones with attendance recorded.
  ///
  /// `is_ended` is not sent: an event can be over and attended before its
  /// end time passes -- a volunteer checks people in while it is running --
  /// and filtering on it would hide today's certificate until tomorrow.
  @override
  Future<List<Certificate>> getMyCertificates() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/list',
      queryParameters: {
        'is_registered': true,
        'limit': 100,
        'offset': 0,
      },
    );

    final items = (response.data?['items'] as List<dynamic>?) ?? const [];
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
  Future<CertificateStyle> getStyle(String ticketId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/certificates/$ticketId/style',
    );
    return CertificateStyle.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}
