import 'package:go_router/go_router.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_verify_page.dart';

/// Batch C's profile routes.
final List<RouteBase> profileRoutes = [
  // Is this certificate genuine? Public: anyone handed a certificate may
  // check it, with or without an account. `/verify/certificates/{code}`
  // checks one at once: the printed number (CERT-...), the QR's text or a
  // ticket id.
  GoRoute(
    path: '/verify/certificates',
    name: 'verifyCertificate',
    builder: (context, state) => CertificateVerifyPage(
      initialCode: state.uri.queryParameters['code'] ?? '',
    ),
    routes: [
      GoRoute(
        path: ':code',
        name: 'verifyCertificateCode',
        builder: (context, state) => CertificateVerifyPage(
          initialCode: state.pathParameters['code'] ?? '',
        ),
      ),
    ],
  ),
];
