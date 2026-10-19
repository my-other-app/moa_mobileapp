import 'package:finnet/features/auth/data/services/password_reset_service.dart';

/// Stands in for the server in the cubit's tests.
class FakePasswordResetService implements PasswordResetService {
  final requested = <String>[];
  final resets = <Map<String, String?>>[];

  /// What the next requestCode / reset does: nothing / tokens, or a refusal.
  Object? nextRequest;
  Object nextReset =
      const PasswordResetTokens(accessToken: 'access', refreshToken: 'refresh');

  @override
  Future<void> requestCode(String email) async {
    requested.add(email);
    final next = nextRequest;
    if (next != null) throw next;
  }

  @override
  Future<PasswordResetTokens> reset({
    required String email,
    required String code,
    required String newPassword,
    String? totpCode,
  }) async {
    resets.add({
      'email': email,
      'code': code,
      'new_password': newPassword,
      'totp_code': totpCode,
    });
    final next = nextReset;
    if (next is PasswordResetException) throw next;
    return next as PasswordResetTokens;
  }
}
