import 'package:finnet/features/auth/data/services/email_verification_service.dart';

/// Stands in for the server: each call does what the test set up next, and
/// records what it was asked.
class FakeEmailVerificationService implements EmailVerificationService {
  int sendCalls = 0;
  final List<String> verified = [];

  /// What the next sendCode does: a sent code, or a refusal to throw.
  Object nextSend =
      const EmailCodeSent(email: 'a@b.co', expiresIn: 900, retryAfter: 60);

  /// What the next verify does: a result, or a refusal to throw.
  Object nextVerify = const EmailVerifiedResult();

  @override
  Future<EmailCodeSent> sendCode() async {
    sendCalls++;
    final next = nextSend;
    if (next is EmailVerificationException) throw next;
    return next as EmailCodeSent;
  }

  @override
  Future<EmailVerifiedResult> verify(String code) async {
    verified.add(code);
    final next = nextVerify;
    if (next is EmailVerificationException) throw next;
    return next as EmailVerifiedResult;
  }
}
