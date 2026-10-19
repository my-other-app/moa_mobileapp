import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/pages/forgot_password_page.dart';

/// Batch C's sign-in routes. Under `/auth`, so they open signed out.
final List<RouteBase> authRoutes = [
  // A forgotten password: a code to the address, then a new password,
  // which signs the person in. `extra: {'email': ...}` (or `?email=`)
  // starts it with the address typed on the sign-in sheet.
  GoRoute(
    path: '/auth/forgot-password',
    name: 'forgotPassword',
    builder: (context, state) {
      final extra = state.extra;
      final email = extra is Map ? extra['email'] : null;
      return ForgotPasswordPage(
        initialEmail:
            email is String ? email : state.uri.queryParameters['email'] ?? '',
      );
    },
  ),
];
