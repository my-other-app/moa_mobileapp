import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/data/services/email_verification_service.dart';
import 'package:finnet/features/auth/presentation/cubits/email_verification_cubit.dart';
import 'package:finnet/features/auth/presentation/widgets/six_digit_code_field.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// "Verify your email": the six-digit code sent to the address an
/// email/password account signed up with.
///
/// Verifying is what lets tickets booked on the website with this address
/// come into the account. Nobody is blocked by it: "Verify later" carries on
/// exactly as if the screen had not been there.
class VerifyEmailPage extends ConsumerStatefulWidget {
  final String email;

  /// Opened straight after signing up: the sign-up already sent a code, and
  /// finishing or skipping carries on into onboarding (the profile check).
  /// Otherwise it was opened from the banner or Settings: it asks for a code
  /// on opening, and finishing goes back where it came from.
  final bool onboarding;

  /// Handed on to the profile check, as the sign-up would have.
  final String accessToken;
  final String profileUrl;

  /// For tests; the real one otherwise.
  final EmailVerificationService? service;

  const VerifyEmailPage({
    super.key,
    required this.email,
    this.onboarding = false,
    this.accessToken = '',
    this.profileUrl = '',
    this.service,
  });

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  static const _ink = Color(0xFF2C333D);
  static const _accent = Color(0xFF17A58F);
  static const _error = Color(0xFFCC0000);

  late final EmailVerificationCubit _cubit;
  final _controller = TextEditingController();
  EmailVerificationState _state = const EmailVerificationState();
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _cubit = EmailVerificationCubit(
      service: widget.service ?? EmailVerificationService(),
    );
    _cubit.onStateChanged = _onState;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cubit.start(codeAlreadySent: widget.onboarding);
    });
  }

  @override
  void dispose() {
    _cubit.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onState(EmailVerificationState state) {
    if (!mounted) return;
    final previous = _state;
    setState(() => _state = state);
    if (state.status == EmailVerificationStatus.verified &&
        previous.status != EmailVerificationStatus.verified) {
      _finish(verified: true);
      return;
    }
    // A wrong or dead code is cleared so the next one can be typed straight in.
    if (state.error != null &&
        previous.status == EmailVerificationStatus.verifying) {
      _controller.clear();
    }
  }

  void _submit([String? code]) {
    final typed = code ?? _controller.text;
    if (typed.length != SixDigitCodeField.length) return;
    _cubit.verify(typed);
  }

  void _finish({required bool verified}) {
    if (_left || !mounted) return;
    _left = true;
    if (verified) {
      final n = _state.registrationsTransferred;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(n > 0
            ? 'Email verified. $n ${n == 1 ? 'ticket' : 'tickets'} from the website ${n == 1 ? 'is' : 'are'} now in your account.'
            : 'Email verified.'),
      ));
    }
    if (widget.onboarding) {
      context.go('/auth/profile-check', extra: {
        'accessToken': widget.accessToken,
        'profileUrl': widget.profileUrl,
      });
      return;
    }
    if (verified) {
      // The banner and the Settings row read this; they go once it says verified.
      ref.read(profileProvider.notifier).loadProfile(force: true);
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  static String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final busy = state.status == EmailVerificationStatus.verifying;
    final canVerify =
        state.canSubmit && _controller.text.length == SixDigitCodeField.length;

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
                  if (!widget.onboarding)
                    IconButton(
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: const Icon(Icons.arrow_back, color: _ink),
                      onPressed: () => _finish(verified: false),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verify your email',
                    style: TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 40,
                      fontFamily: 'BebasNeue',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: 'We sent a 6-digit code to ',
                      children: [
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontFamily: 'DMSans',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'It expires in 15 minutes. Check your spam folder if it isn\'t there.',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      fontFamily: 'DMSans',
                    ),
                  ),
                  const SizedBox(height: 32),
                  SixDigitCodeField(
                    key: const ValueKey('verify-email-code'),
                    controller: _controller,
                    enabled: !busy &&
                        state.status != EmailVerificationStatus.verified,
                    hasError: state.error != null && !state.errorIsNotice,
                    onChanged: (_) {
                      _cubit.clearError();
                      setState(() {});
                    },
                    onCompleted: _submit,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: state.error == null
                        ? null
                        : Text(
                            state.error!,
                            key: const ValueKey('verify-email-error'),
                            style: TextStyle(
                              color: state.errorIsNotice
                                  ? const Color(0xFF6B7280)
                                  : _error,
                              fontSize: 13,
                              fontFamily: 'DMSans',
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _verifyButton(enabled: canVerify, busy: busy),
                  const SizedBox(height: 16),
                  Center(child: _resend(state)),
                  Center(
                    child: TextButton(
                      key: const ValueKey('verify-email-later'),
                      onPressed: busy ? null : () => _finish(verified: false),
                      child: const Text(
                        'Verify later',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontFamily: 'DMSans',
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verifying brings in tickets you booked on the website with this email.',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      fontFamily: 'DMSans',
                    ),
                  ),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verifyButton({required bool enabled, required bool busy}) {
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
          key: const ValueKey('verify-email-submit'),
          onTap: enabled ? _submit : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'VERIFY',
                    style: TextStyle(
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

  Widget _resend(EmailVerificationState state) {
    if (state.status == EmailVerificationStatus.sending) {
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
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Resend code in ${_clock(state.resendIn)}',
          key: const ValueKey('verify-email-countdown'),
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontFamily: 'DMSans',
          ),
        ),
      );
    }
    return TextButton(
      key: const ValueKey('verify-email-resend'),
      onPressed: state.canResend
          ? () {
              _controller.clear();
              _cubit.sendCode();
            }
          : null,
      child: const Text(
        "Didn't get it? Resend code",
        style: TextStyle(
          color: _accent,
          fontSize: 14,
          fontFamily: 'DMSans',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
