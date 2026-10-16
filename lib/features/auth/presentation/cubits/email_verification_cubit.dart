import 'dart:async';

import 'package:finnet/features/auth/data/services/email_verification_service.dart';

enum EmailVerificationStatus {
  /// Waiting for the code to be typed.
  idle,

  /// Asking the server to send a code.
  sending,

  /// Checking a typed code.
  verifying,

  /// Done: the address is verified.
  verified,
}

/// Everything the verify screen shows.
class EmailVerificationState {
  final EmailVerificationStatus status;

  /// Seconds before another code may be asked for; 0 when it may be now.
  final int resendIn;

  /// What went wrong last, worded for the person; null when nothing did.
  final String? error;
  final EmailVerificationErrorKind? errorKind;

  /// Tries left on the current code, when the server said.
  final int? attemptsLeft;

  /// Whether the last code sent can still be typed. False once it is dead
  /// (five wrong tries) until a new one is sent.
  final bool codeUsable;

  /// Registrations booked on the website that came in on verifying.
  final int registrationsTransferred;

  const EmailVerificationState({
    this.status = EmailVerificationStatus.idle,
    this.resendIn = 0,
    this.error,
    this.errorKind,
    this.attemptsLeft,
    this.codeUsable = true,
    this.registrationsTransferred = 0,
  });

  bool get isBusy =>
      status == EmailVerificationStatus.sending ||
      status == EmailVerificationStatus.verifying;

  bool get canResend =>
      resendIn == 0 && !isBusy && status != EmailVerificationStatus.verified;

  bool get canSubmit =>
      status == EmailVerificationStatus.idle && codeUsable;

  /// A refusal to send again yet is information, not a failure.
  bool get errorIsNotice => errorKind == EmailVerificationErrorKind.throttled;

  EmailVerificationState copyWith({
    EmailVerificationStatus? status,
    int? resendIn,
    String? error,
    EmailVerificationErrorKind? errorKind,
    int? attemptsLeft,
    bool? codeUsable,
    int? registrationsTransferred,
    bool clearError = false,
  }) {
    return EmailVerificationState(
      status: status ?? this.status,
      resendIn: resendIn ?? this.resendIn,
      error: clearError ? null : (error ?? this.error),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      attemptsLeft: clearError ? null : (attemptsLeft ?? this.attemptsLeft),
      codeUsable: codeUsable ?? this.codeUsable,
      registrationsTransferred:
          registrationsTransferred ?? this.registrationsTransferred,
    );
  }
}

/// Sends and checks the email verification code, and runs the resend
/// countdown. Callback-based like [LoginCubit]: the page listens through
/// [onStateChanged] and calls [dispose] when it goes.
class EmailVerificationCubit {
  final EmailVerificationService service;

  /// Seconds to wait before the first resend when a code went out just
  /// before this screen opened (sign-up sends one).
  final int initialResendIn;

  EmailVerificationState _state = const EmailVerificationState();
  EmailVerificationState get state => _state;

  void Function(EmailVerificationState)? onStateChanged;

  Timer? _countdown;
  bool _disposed = false;

  EmailVerificationCubit({required this.service, this.initialResendIn = 60});

  void _emit(EmailVerificationState next) {
    if (_disposed) return;
    _state = next;
    onStateChanged?.call(_state);
  }

  /// Opens the screen: asks for a code unless one was just sent.
  Future<void> start({required bool codeAlreadySent}) async {
    if (codeAlreadySent) {
      _startCountdown(initialResendIn);
      return;
    }
    await sendCode();
  }

  /// Asks for a (new) code. Any earlier code stops working on the server.
  Future<void> sendCode() async {
    if (_state.isBusy || _state.status == EmailVerificationStatus.verified) {
      return;
    }
    _emit(_state.copyWith(
        status: EmailVerificationStatus.sending, clearError: true));
    try {
      final sent = await service.sendCode();
      _emit(_state.copyWith(
          status: EmailVerificationStatus.idle, codeUsable: true));
      _startCountdown(sent.retryAfter);
    } on EmailVerificationException catch (e) {
      if (e.kind == EmailVerificationErrorKind.alreadyVerified) {
        _verified(0);
        return;
      }
      _emit(_state.copyWith(
        status: EmailVerificationStatus.idle,
        error: e.message,
        errorKind: e.kind,
      ));
      if (e.retryAfter != null) _startCountdown(e.retryAfter!);
    } catch (_) {
      _emit(_state.copyWith(
        status: EmailVerificationStatus.idle,
        error: 'Could not send the code. Please try again.',
        errorKind: EmailVerificationErrorKind.unknown,
      ));
    }
  }

  /// Checks a typed code.
  Future<void> verify(String code) async {
    if (!_state.canSubmit || code.length != 6) return;
    _emit(_state.copyWith(
        status: EmailVerificationStatus.verifying, clearError: true));
    try {
      final result = await service.verify(code);
      _verified(result.registrationsTransferred);
    } on EmailVerificationException catch (e) {
      if (e.kind == EmailVerificationErrorKind.alreadyVerified) {
        _verified(0);
        return;
      }
      final dead = e.kind == EmailVerificationErrorKind.tooManyAttempts ||
          e.kind == EmailVerificationErrorKind.expired;
      _emit(_state.copyWith(
        status: EmailVerificationStatus.idle,
        error: e.message,
        errorKind: e.kind,
        attemptsLeft: e.attemptsLeft,
        codeUsable: dead ? false : null,
      ));
    } catch (_) {
      _emit(_state.copyWith(
        status: EmailVerificationStatus.idle,
        error: 'Could not check the code. Please try again.',
        errorKind: EmailVerificationErrorKind.unknown,
      ));
    }
  }

  /// Clears a shown error once the person starts typing again.
  void clearError() {
    if (_state.error == null || _state.errorIsNotice) return;
    _emit(_state.copyWith(clearError: true));
  }

  void _verified(int registrations) {
    _countdown?.cancel();
    _emit(_state.copyWith(
      status: EmailVerificationStatus.verified,
      resendIn: 0,
      registrationsTransferred: registrations,
      clearError: true,
    ));
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _emit(_state.copyWith(resendIn: seconds < 0 ? 0 : seconds));
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = _state.resendIn - 1;
      if (left <= 0) {
        timer.cancel();
        // The wait is over, so a "wait before asking again" notice is too.
        _emit(_state.errorIsNotice
            ? _state.copyWith(resendIn: 0, clearError: true)
            : _state.copyWith(resendIn: 0));
      } else {
        _emit(_state.copyWith(resendIn: left));
      }
    });
  }

  void dispose() {
    _disposed = true;
    _countdown?.cancel();
    onStateChanged = null;
  }
}
