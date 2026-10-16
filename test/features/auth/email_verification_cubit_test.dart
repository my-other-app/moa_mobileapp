import 'package:finnet/features/auth/data/services/email_verification_service.dart';
import 'package:finnet/features/auth/presentation/cubits/email_verification_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'email_verification_fakes.dart';

const wrongCode = EmailVerificationException(
  EmailVerificationErrorKind.wrongCode,
  "That code isn't right. 4 tries left.",
  attemptsLeft: 4,
);

const locked = EmailVerificationException(
  EmailVerificationErrorKind.tooManyAttempts,
  'Too many wrong tries. Ask for a new code.',
  attemptsLeft: 0,
);

void main() {
  late FakeEmailVerificationService service;
  late EmailVerificationCubit cubit;
  late List<EmailVerificationState> states;

  setUp(() {
    service = FakeEmailVerificationService();
    cubit = EmailVerificationCubit(service: service);
    states = [];
    cubit.onStateChanged = states.add;
  });

  tearDown(() => cubit.dispose());

  group('opening the screen', () {
    test('right after sign-up it does not send again, and waits a minute',
        () async {
      await cubit.start(codeAlreadySent: true);

      expect(service.sendCalls, 0);
      expect(cubit.state.resendIn, 60);
      expect(cubit.state.canResend, isFalse);
      expect(cubit.state.canSubmit, isTrue);
    });

    test('from the banner it asks for a code, and waits what the server says',
        () async {
      service.nextSend =
          const EmailCodeSent(email: 'a@b.co', expiresIn: 900, retryAfter: 45);

      await cubit.start(codeAlreadySent: false);

      expect(service.sendCalls, 1);
      expect(cubit.state.status, EmailVerificationStatus.idle);
      expect(cubit.state.resendIn, 45);
      expect(states.first.status, EmailVerificationStatus.sending);
    });

    test('asked too soon: the wait is the server\'s retry_after, as a notice',
        () async {
      service.nextSend = const EmailVerificationException(
        EmailVerificationErrorKind.throttled,
        'We just sent you a code. You can ask for another in 30 seconds.',
        retryAfter: 30,
      );

      await cubit.start(codeAlreadySent: false);

      expect(cubit.state.resendIn, 30);
      expect(cubit.state.errorIsNotice, isTrue);
      expect(cubit.state.error, contains('30 seconds'));
      // A notice, not a failure: the code already sent can still be typed.
      expect(cubit.state.canSubmit, isTrue);
    });
  });

  testWidgets('the resend countdown runs down to zero, then resend is allowed',
      (tester) async {
    final cubit = EmailVerificationCubit(
        service: FakeEmailVerificationService(), initialResendIn: 3);
    addTearDown(cubit.dispose);
    await cubit.start(codeAlreadySent: true);
    expect(cubit.state.resendIn, 3);

    await tester.pump(const Duration(seconds: 1));
    expect(cubit.state.resendIn, 2);
    await tester.pump(const Duration(seconds: 2));
    expect(cubit.state.resendIn, 0);
    expect(cubit.state.canResend, isTrue);
  });

  group('checking a code', () {
    setUp(() => cubit.start(codeAlreadySent: true));

    test('a wrong code says how many tries are left and keeps the code usable',
        () async {
      service.nextVerify = wrongCode;

      await cubit.verify('000000');

      expect(cubit.state.errorKind, EmailVerificationErrorKind.wrongCode);
      expect(cubit.state.attemptsLeft, 4);
      expect(cubit.state.error, "That code isn't right. 4 tries left.");
      expect(cubit.state.canSubmit, isTrue);

      cubit.clearError();
      expect(cubit.state.error, isNull);
    });

    test('five wrong tries kill the code until a new one is sent', () async {
      service.nextVerify = locked;
      await cubit.verify('000000');
      expect(cubit.state.errorKind, EmailVerificationErrorKind.tooManyAttempts);
      expect(cubit.state.canSubmit, isFalse);

      await cubit.verify('123456');
      expect(service.verified, ['000000']);

      // A new code makes the field take codes again.
      await cubit.sendCode();
      expect(cubit.state.codeUsable, isTrue);
      expect(cubit.state.error, isNull);
      service.nextVerify = const EmailVerifiedResult();
      await cubit.verify('123456');
      expect(cubit.state.status, EmailVerificationStatus.verified);
    });

    test('an expired code asks for a new one', () async {
      service.nextVerify = const EmailVerificationException(
        EmailVerificationErrorKind.expired,
        'That code has expired. Ask for a new one.',
      );
      await cubit.verify('123456');
      expect(cubit.state.errorKind, EmailVerificationErrorKind.expired);
      expect(cubit.state.canSubmit, isFalse);
    });

    test('the right code verifies, with what came in from the website',
        () async {
      service.nextVerify = const EmailVerifiedResult(
          merged: true, registrationsTransferred: 2);

      await cubit.verify('123456');

      expect(cubit.state.status, EmailVerificationStatus.verified);
      expect(cubit.state.registrationsTransferred, 2);
      expect(cubit.state.resendIn, 0);
      expect(states.map((s) => s.status), contains(EmailVerificationStatus.verifying));
    });

    test('already verified elsewhere counts as verified', () async {
      service.nextVerify = const EmailVerificationException(
        EmailVerificationErrorKind.alreadyVerified,
        'Your email is already verified.',
      );
      await cubit.verify('123456');
      expect(cubit.state.status, EmailVerificationStatus.verified);
    });

    test('fewer than six digits are not sent', () async {
      await cubit.verify('123');
      expect(service.verified, isEmpty);
    });
  });
}
