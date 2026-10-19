import 'package:flutter/material.dart';
import 'package:finnet/features/auth/presentation/widgets/six_digit_code_field.dart';

/// The second step of signing in, for an account with two-step
/// verification on: the six digits from the authenticator app, or one of
/// the account's recovery codes.
///
/// [onSubmit] tries the code and answers with why it was refused, or null
/// when it was accepted -- the screen behind then closes this sheet and
/// carries on signing in.
class TwoStepSheet extends StatefulWidget {
  final String email;
  final Future<String?> Function(String code) onSubmit;

  /// Shown on opening: why the last code was refused, if one was.
  final String? initialError;

  const TwoStepSheet({
    super.key,
    required this.email,
    required this.onSubmit,
    this.initialError,
  });

  @override
  State<TwoStepSheet> createState() => _TwoStepSheetState();
}

class _TwoStepSheetState extends State<TwoStepSheet> {
  static const _ink = Color(0xFF2C333D);
  static const _accent = Color(0xFF17A58F);
  static const _error = Color(0xFFCC0000);

  final _digits = TextEditingController();
  final _recovery = TextEditingController();
  bool _useRecovery = false;
  bool _busy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _errorText = widget.initialError;
  }

  @override
  void dispose() {
    _digits.dispose();
    _recovery.dispose();
    super.dispose();
  }

  String get _code => (_useRecovery ? _recovery.text : _digits.text).trim();

  bool get _ready => _useRecovery
      ? _code.length >= 4
      : _code.length == SixDigitCodeField.length;

  Future<void> _submit([String? _]) async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final refused = await widget.onSubmit(_code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorText = refused;
    });
    if (refused != null) {
      // Cleared, so the next code can go straight in.
      _digits.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('two-step-sheet'),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Two-step verification',
              style: TextStyle(
                fontSize: 28,
                fontFamily: 'BebasNeue',
                fontWeight: FontWeight.w400,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _useRecovery
                  ? 'Enter one of the recovery codes you saved for '
                      '${widget.email}. Each one works once.'
                  : 'Enter the 6-digit code from your authenticator app for '
                      '${widget.email}.',
              style: const TextStyle(fontSize: 15, color: _ink),
            ),
            const SizedBox(height: 20),
            if (_useRecovery)
              TextField(
                key: const ValueKey('two-step-recovery'),
                controller: _recovery,
                enabled: !_busy,
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _errorText = null),
                onSubmitted: _submit,
                decoration: InputDecoration(
                  labelText: 'Recovery code',
                  hintText: 'abcd-1234-ef56-7890',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              SixDigitCodeField(
                key: const ValueKey('two-step-code'),
                controller: _digits,
                enabled: !_busy,
                hasError: _errorText != null,
                onChanged: (_) => setState(() => _errorText = null),
                onCompleted: _submit,
              ),
            SizedBox(
              height: 44,
              child: _errorText == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorText!,
                        key: const ValueKey('two-step-error'),
                        style: const TextStyle(color: _error, fontSize: 13),
                      ),
                    ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                key: const ValueKey('two-step-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  disabledBackgroundColor: _ink.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _busy || !_ready ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'VERIFY',
                        style: TextStyle(
                          fontSize: 22,
                          fontFamily: 'BebasNeue',
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                key: const ValueKey('two-step-switch'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _useRecovery = !_useRecovery;
                          _errorText = null;
                        }),
                child: Text(
                  _useRecovery
                      ? 'Use the authenticator app instead'
                      : 'Use a recovery code instead',
                  style: const TextStyle(
                      color: _accent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Center(
              child: TextButton(
                key: const ValueKey('two-step-cancel'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: _ink)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
