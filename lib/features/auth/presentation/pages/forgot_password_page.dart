import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/password_reset_service.dart';
import 'package:finnet/features/auth/presentation/cubits/password_reset_cubit.dart';
import 'package:finnet/features/auth/presentation/widgets/six_digit_code_field.dart';

/// "Forgot your password?": a code to the address, then the code and a new
/// password -- which signs the person in. `/auth/forgot-password`.
///
/// Never says whether an address has an account: the server answers the
/// same either way, and so does this screen.
class ForgotPasswordPage extends StatefulWidget {
  /// What was typed on the sign-in sheet, to start from.
  final String initialEmail;

  /// For tests; the real ones otherwise.
  final PasswordResetService? service;
  final SecureStorageService? storage;

  const ForgotPasswordPage({
    super.key,
    this.initialEmail = '',
    this.service,
    this.storage,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _ink = Color(0xFF2C333D);
  static const _accent = Color(0xFF17A58F);
  static const _error = Color(0xFFCC0000);
  static const _muted = Color(0xFF6B7280);

  late final PasswordResetCubit _cubit;
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _totp = TextEditingController();
  final _passwordFocus = FocusNode();
  PasswordResetState _state = const PasswordResetState();
  bool _showPassword = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
    _cubit = PasswordResetCubit(
      service: widget.service ?? PasswordResetService(),
    );
    _cubit.onStateChanged = _onState;
  }

  @override
  void dispose() {
    _cubit.dispose();
    for (final c in [_email, _code, _password, _confirm, _totp]) {
      c.dispose();
    }
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onState(PasswordResetState state) {
    if (!mounted) return;
    final previous = _state;
    setState(() => _state = state);
    if (state.step == PasswordResetStep.done && state.tokens != null) {
      _finish(state.tokens!);
      return;
    }
    // A wrong or dead code is cleared so the next one can be typed straight in.
    if (previous.isResetting &&
        (state.errorKind == PasswordResetErrorKind.wrongCode ||
            !state.codeUsable)) {
      _code.clear();
    }
    // A new code: the old one's digits go.
    if (previous.isSending && !state.isSending && state.error == null) {
      _code.clear();
    }
  }

  /// Signed in with the new password: store the session and go on the way
  /// any sign-in does, through the profile check.
  Future<void> _finish(PasswordResetTokens tokens) async {
    if (_finished) return;
    _finished = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await (widget.storage ?? SecureStorageService()).saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
    } catch (e) {
      debugPrint('ForgotPassword: could not store the session: $e');
      _finished = false;
      if (!mounted) return;
      setState(() => _state = _state.copyWith(
            error: 'Your password is changed. Sign in with it to continue.',
          ));
      return;
    }
    if (!mounted) return;
    messenger?.showSnackBar(const SnackBar(
      content: Text("Password changed. You're signed in."),
    ));
    context.go(withSignInFrom('/auth/profile-check', signInFromOf(context)),
        extra: {
      'accessToken': tokens.accessToken,
      'profileUrl': '',
    });
  }

  void _send() {
    FocusScope.of(context).unfocus();
    _cubit.requestCode(_email.text);
  }

  void _reset() {
    FocusScope.of(context).unfocus();
    _cubit.reset(
      code: _code.text,
      newPassword: _password.text,
      confirmPassword: _confirm.text,
      totpCode: _totp.text,
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(withSignInFrom('/auth/onboarding', signInFromOf(context)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCode = _state.step != PasswordResetStep.email;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/grass.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  IconButton(
                    key: const ValueKey('reset-back'),
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.arrow_back, color: _ink),
                    onPressed: _state.isBusy ? null : _back,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    onCode ? 'Reset your password' : 'Forgot your password?',
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 40,
                      fontFamily: 'BebasNeue',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (onCode) ..._codeStep() else ..._emailStep(),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _emailStep() {
    return [
      const Text(
        "Enter the email you sign in with. We'll send you a 6-digit code to "
        'set a new password.',
        style: TextStyle(color: _ink, fontSize: 16, fontFamily: 'DMSans'),
      ),
      const SizedBox(height: 24),
      TextField(
        key: const ValueKey('reset-email'),
        controller: _email,
        enabled: !_state.isSending,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        textInputAction: TextInputAction.send,
        onChanged: (_) => _cubit.clearError(),
        onSubmitted: (_) => _send(),
        decoration: _decoration('Email', Icons.email_outlined),
      ),
      _errorLine(),
      _button(
        key: 'reset-send',
        label: 'SEND CODE',
        busy: _state.isSending,
        onTap: _send,
      ),
      const SizedBox(height: 20),
      const Text(
        'Signed up with Google or Apple? Those accounts have no password: '
        'sign in with the same button you used before.',
        style: TextStyle(color: _muted, fontSize: 13, fontFamily: 'DMSans'),
      ),
    ];
  }

  List<Widget> _codeStep() {
    final state = _state;
    return [
      Text.rich(
        TextSpan(
          text: 'If ',
          children: [
            TextSpan(
              text: state.email,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(
              text: ' has an account with a password, a 6-digit code is on '
                  'its way to it.',
            ),
          ],
        ),
        style: const TextStyle(color: _ink, fontSize: 16, fontFamily: 'DMSans'),
      ),
      const SizedBox(height: 4),
      const Text(
        "It expires in 15 minutes. Check your spam folder if it isn't there.",
        style: TextStyle(color: _muted, fontSize: 13, fontFamily: 'DMSans'),
      ),
      const SizedBox(height: 24),
      SixDigitCodeField(
        key: const ValueKey('reset-code'),
        controller: _code,
        enabled: !state.isResetting && state.codeUsable,
        hasError: state.errorKind == PasswordResetErrorKind.wrongCode,
        onChanged: (_) => _cubit.clearError(),
        onCompleted: (_) => _passwordFocus.requestFocus(),
      ),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('reset-new-password'),
        controller: _password,
        focusNode: _passwordFocus,
        enabled: !state.isResetting,
        obscureText: !_showPassword,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        onChanged: (_) => _cubit.clearError(),
        decoration: _decoration('New password', Icons.lock_outlined).copyWith(
          helperText: 'At least $minPasswordLength characters',
          suffixIcon: IconButton(
            tooltip: _showPassword ? 'Hide password' : 'Show password',
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('reset-confirm-password'),
        controller: _confirm,
        enabled: !state.isResetting,
        obscureText: !_showPassword,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction:
            state.needsTotp ? TextInputAction.next : TextInputAction.done,
        onChanged: (_) => _cubit.clearError(),
        onSubmitted: state.needsTotp ? null : (_) => _reset(),
        decoration: _decoration('New password again', Icons.lock_outlined),
      ),
      if (state.needsTotp) ...[
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('reset-totp'),
          controller: _totp,
          enabled: !state.isResetting,
          autocorrect: false,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          onChanged: (_) => _cubit.clearError(),
          onSubmitted: (_) => _reset(),
          decoration: _decoration(
            'Authenticator code',
            Icons.verified_user_outlined,
          ).copyWith(
            helperText: 'From your authenticator app, or a recovery code',
          ),
        ),
      ],
      _errorLine(),
      _button(
        key: 'reset-submit',
        label: 'RESET PASSWORD',
        busy: state.isResetting,
        onTap: state.codeUsable ? _reset : null,
      ),
      const SizedBox(height: 12),
      Center(child: _resend()),
      Center(
        child: TextButton(
          key: const ValueKey('reset-change-email'),
          onPressed: state.isBusy ? null : _cubit.changeEmail,
          child: const Text(
            'Use a different email',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontFamily: 'DMSans',
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _errorLine() {
    final error = _state.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: error == null
          ? const SizedBox(height: 18)
          : Text(
              error,
              key: const ValueKey('reset-error'),
              style: const TextStyle(
                color: _error,
                fontSize: 13,
                fontFamily: 'DMSans',
              ),
            ),
    );
  }

  Widget _resend() {
    final state = _state;
    if (state.isSending) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
        ),
      );
    }
    if (state.resendIn > 0) {
      final m = state.resendIn ~/ 60;
      final s = (state.resendIn % 60).toString().padLeft(2, '0');
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Send a new code in $m:$s',
          key: const ValueKey('reset-countdown'),
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
      );
    }
    return TextButton(
      key: const ValueKey('reset-resend'),
      onPressed: state.canResend ? _cubit.resend : null,
      child: Text(
        state.codeUsable ? "Didn't get it? Send a new code" : 'Send a new code',
        style: const TextStyle(
          color: _accent,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _button({
    required String key,
    required String label,
    required bool busy,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null && !busy;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: ShapeDecoration(
        color: enabled || busy ? _ink : _ink.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(key),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'BebasNeue',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
