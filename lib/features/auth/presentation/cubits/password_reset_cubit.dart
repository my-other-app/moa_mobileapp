import 'dart:async';

import 'package:finnet/features/auth/data/services/password_reset_service.dart';

enum PasswordResetStep {
  /// Asking for the address.
  email,

  /// A code has been asked for: waiting for it and the new password.
  code,

  /// The password is set and a session is open ([PasswordResetState.tokens]).
  done,
}

/// Everything the forgotten-password screen shows.
class PasswordResetState {
  final PasswordResetStep step;

  /// The address the code was asked for.
  final String email;

  /// Asking the server to send a code.
  final bool isSending;

  /// Checking the code and setting the password.
  final bool isResetting;

  /// Seconds before another code may be asked for; 0 when it may be now.
  final int resendIn;

  /// What went wrong last, worded for the person; null when nothing did.
  final String? error;
  final PasswordResetErrorKind? errorKind;

  /// Whether the last code sent can still be typed. False once it is dead
  /// (expired, or five wrong tries) until a new one is asked for.
  final bool codeUsable;

  /// The account has two-step verification on: the authenticator's code is
  /// needed with the new password.
  final bool needsTotp;

  /// The new session, once the reset went through.
  final PasswordResetTokens? tokens;

  const PasswordResetState({
    this.step = PasswordResetStep.email,
    this.email = '',
    this.isSending = false,
    this.isResetting = false,
    this.resendIn = 0,
    this.error,
    this.errorKind,
    this.codeUsable = true,
    this.needsTotp = false,
    this.tokens,
  });

  bool get isBusy => isSending || isResetting;

  bool get canResend =>
      resendIn == 0 && !isBusy && step == PasswordResetStep.code;

  PasswordResetState copyWith({
    PasswordResetStep? step,
    String? email,
    bool? isSending,
    bool? isResetting,
    int? resendIn,
    String? error,
    PasswordResetErrorKind? errorKind,
    bool clearError = false,
    bool? codeUsable,
    bool? needsTotp,
    PasswordResetTokens? tokens,
  }) {
    return PasswordResetState(
      step: step ?? this.step,
      email: email ?? this.email,
      isSending: isSending ?? this.isSending,
      isResetting: isResetting ?? this.isResetting,
      resendIn: resendIn ?? this.resendIn,
      error: clearError ? null : (error ?? this.error),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      codeUsable: codeUsable ?? this.codeUsable,
      needsTotp: needsTotp ?? this.needsTotp,
      tokens: tokens ?? this.tokens,
    );
  }
}

/// Copy the screen and its tests share.
class PasswordResetCopy {
  PasswordResetCopy._();

  static const enterEmail = 'Enter the email address you sign in with.';
  static const enterCode = 'Enter the 6-digit code from the email.';
  static const shortPassword =
      'Use at least $minPasswordLength characters for your new password.';
  static const mismatch = "The two passwords don't match.";
  static const enterTotp = 'Enter the code from your authenticator app.';
}

/// The shortest password the server takes (`PasswordResetConfirm`), the
/// same rule as signing up.
const minPasswordLength = 6;

/// Asks for a reset code, then sets the new password with it. Callback-based
/// like [EmailVerificationCubit]: the page listens through [onStateChanged]
/// and calls [dispose] when it goes.
class PasswordResetCubit {
  final PasswordResetService service;

  /// Seconds between codes: the server sends at most one a minute to an
  /// address, and says nothing when it sends none.
  final int resendWait;

  PasswordResetState _state = const PasswordResetState();
  PasswordResetState get state => _state;

  void Function(PasswordResetState)? onStateChanged;

  Timer? _countdown;
  bool _disposed = false;

  PasswordResetCubit({required this.service, this.resendWait = 60});

  void _emit(PasswordResetState next) {
    if (_disposed) return;
    _state = next;
    onStateChanged?.call(_state);
  }

  /// Ask for a code for [email]. The answer is the same whether or not the
  /// address has an account, so the next step always follows.
  Future<void> requestCode(String email) async {
    final address = email.trim();
    if (_state.isBusy) return;
    if (address.isEmpty || !address.contains('@')) {
      _emit(_state.copyWith(
        error: PasswordResetCopy.enterEmail,
        errorKind: PasswordResetErrorKind.invalidInput,
      ));
      return;
    }
    await _send(address);
  }

  /// Ask for a new code for the same address.
  Future<void> resend() async {
    if (!_state.canResend) return;
    await _send(_state.email);
  }

  Future<void> _send(String address) async {
    _emit(_state.copyWith(email: address, isSending: true, clearError: true));
    try {
      await service.requestCode(address);
      _emit(_state.copyWith(
        step: PasswordResetStep.code,
        isSending: false,
        codeUsable: true,
      ));
      _startCountdown(resendWait);
    } on PasswordResetException catch (e) {
      _emit(_state.copyWith(
        isSending: false,
        error: e.message,
        errorKind: e.kind,
      ));
      if (e.kind == PasswordResetErrorKind.throttled) {
        _startCountdown(resendWait);
      }
    } catch (_) {
      _emit(_state.copyWith(
        isSending: false,
        error: "We couldn't send the code. Please try again.",
        errorKind: PasswordResetErrorKind.unknown,
      ));
    }
  }

  /// Check [code] and set [newPassword]. [totpCode] is the authenticator's,
  /// for an account with two-step verification on.
  Future<void> reset({
    required String code,
    required String newPassword,
    required String confirmPassword,
    String? totpCode,
  }) async {
    if (_state.isBusy || _state.step != PasswordResetStep.code) return;
    final typed = code.replaceAll(RegExp(r'\s'), '');
    String? problem;
    if (!_state.codeUsable) {
      problem = 'That code no longer works. Ask for a new one.';
    } else if (typed.length != 6) {
      problem = PasswordResetCopy.enterCode;
    } else if (newPassword.length < minPasswordLength) {
      problem = PasswordResetCopy.shortPassword;
    } else if (newPassword != confirmPassword) {
      problem = PasswordResetCopy.mismatch;
    } else if (_state.needsTotp && (totpCode ?? '').trim().isEmpty) {
      problem = PasswordResetCopy.enterTotp;
    }
    if (problem != null) {
      _emit(_state.copyWith(
        error: problem,
        errorKind: PasswordResetErrorKind.invalidInput,
      ));
      return;
    }

    _emit(_state.copyWith(isResetting: true, clearError: true));
    try {
      final tokens = await service.reset(
        email: _state.email,
        code: typed,
        newPassword: newPassword,
        totpCode: _state.needsTotp ? totpCode : null,
      );
      _countdown?.cancel();
      _emit(_state.copyWith(
        step: PasswordResetStep.done,
        isResetting: false,
        resendIn: 0,
        tokens: tokens,
      ));
    } on PasswordResetException catch (e) {
      _emit(_state.copyWith(
        isResetting: false,
        error: e.message,
        errorKind: e.kind,
        codeUsable: e.needsNewCode ? false : null,
        needsTotp: e.kind == PasswordResetErrorKind.totpRequired ||
                e.kind == PasswordResetErrorKind.totpInvalid
            ? true
            : null,
      ));
    } catch (_) {
      _emit(_state.copyWith(
        isResetting: false,
        error: "We couldn't reset your password. Please try again.",
        errorKind: PasswordResetErrorKind.unknown,
      ));
    }
  }

  /// Back to the address, to correct it.
  void changeEmail() {
    if (_state.isBusy) return;
    _countdown?.cancel();
    _emit(PasswordResetState(email: _state.email));
  }

  /// Clears a shown error once the person starts typing again.
  void clearError() {
    if (_state.error == null) return;
    _emit(_state.copyWith(clearError: true));
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _emit(_state.copyWith(resendIn: seconds < 0 ? 0 : seconds));
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = _state.resendIn - 1;
      if (left <= 0) {
        timer.cancel();
        _emit(_state.copyWith(resendIn: 0));
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
