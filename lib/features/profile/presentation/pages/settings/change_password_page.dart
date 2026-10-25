import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/auth/data/services/change_password_service.dart';
import 'package:finnet/features/auth/presentation/cubits/password_reset_cubit.dart'
    show PasswordResetCopy, minPasswordLength;
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// Settings -> Change Password, for an account that signs in with an email
/// and a password: the current one, then the new one twice, with the rules
/// sign-up has (at least [minPasswordLength] characters).
///
/// Changing it ends every session the account has, this one too, so the
/// page signs in again with the new password and carries on; an account
/// with two-step verification is asked to sign in again instead.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  static const currentKey = ValueKey('change-password-current');
  static const newKey = ValueKey('change-password-new');
  static const confirmKey = ValueKey('change-password-confirm');
  static const saveKey = ValueKey('change-password-save');

  static const sameAsCurrent =
      'Pick a new password, not the one you have now.';
  static const changed = 'Password changed.';
  static const signInAgain =
      'Password changed. Sign in again with your new password.';

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;

  /// What the server said, under the field it is about.
  String? _currentProblem;
  String? _problem;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _currentProblem = null;
      _problem = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final service = ref.read(changePasswordServiceProvider);
    final password = _new.text;
    try {
      await service.change(
          currentPassword: _current.text, newPassword: password);
    } on ChangePasswordException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.kind == ChangePasswordErrorKind.wrongCurrent) {
          _currentProblem = e.message;
        } else {
          _problem = e.message;
        }
      });
      return;
    }

    // Every session ended with the old password, this one too: sign in
    // again with the new one, as the address the account signs in with.
    if (ref.read(profileProvider).profile == null) {
      await ref.read(profileProvider.notifier).loadProfile();
      if (!mounted) return;
    }
    final email = ref.read(profileProvider).profile?.email ?? '';
    final tokens = email.isEmpty
        ? null
        : await service.signInAgain(email: email, password: password);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authStateProvider.notifier);
    if (tokens != null) {
      await auth.renewSession(
          accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
      messenger.showSnackBar(
          const SnackBar(content: Text(ChangePasswordPage.changed)));
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    messenger.showSnackBar(
        const SnackBar(content: Text(ChangePasswordPage.signInAgain)));
    if (mounted) setState(() => _saving = false);
    // The router takes them to sign-in once the session is gone.
    await auth.logout();
  }

  InputDecoration _decoration(String label, {String? error}) =>
      InputDecoration(
        labelText: label,
        errorText: error,
        errorMaxLines: 3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          tooltip: _show ? 'Hide passwords' : 'Show passwords',
          icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _show = !_show),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // The address to sign in again with, read before it is needed.
    ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'CHANGE PASSWORD',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Changing it signs you out on your other devices.',
                style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: ChangePasswordPage.currentKey,
                controller: _current,
                obscureText: !_show,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                decoration: _decoration('Current password',
                    error: _currentProblem),
                onChanged: (_) {
                  if (_currentProblem != null) {
                    setState(() => _currentProblem = null);
                  }
                },
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ChangePasswordPage.newKey,
                controller: _new,
                obscureText: !_show,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: _decoration('New password').copyWith(
                    helperText: 'At least $minPasswordLength characters.'),
                validator: (v) {
                  if (v == null || v.length < minPasswordLength) {
                    return PasswordResetCopy.shortPassword;
                  }
                  if (v == _current.text) {
                    return ChangePasswordPage.sameAsCurrent;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ChangePasswordPage.confirmKey,
                controller: _confirm,
                obscureText: !_show,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saving ? null : _save(),
                decoration: _decoration('New password, again'),
                validator: (v) =>
                    v != _new.text ? PasswordResetCopy.mismatch : null,
              ),
              if (_problem != null) ...[
                const SizedBox(height: 16),
                Text(
                  _problem!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: ChangePasswordPage.saveKey,
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Change password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
