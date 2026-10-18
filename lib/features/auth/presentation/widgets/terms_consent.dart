import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/shared/utils/external_links.dart';

/// "By continuing, you agree to our Terms and Privacy Policy", each a link
/// to the page on the public site.
///
/// On the sign-in screen and the email sheet, so that agreeing to the terms
/// -- which say there is no tolerance for objectionable content, and are
/// what a report or a block enforces -- comes before an account exists
/// (App Store guideline 1.2).
class TermsConsent extends ConsumerStatefulWidget {
  const TermsConsent({super.key, this.color = const Color(0xFF2C333D)});

  /// The text's colour; the links are the same colour, underlined.
  final Color color;

  @override
  ConsumerState<TermsConsent> createState() => _TermsConsentState();
}

class _TermsConsentState extends ConsumerState<TermsConsent> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open(termsUri);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open(privacyPolicyUri);

  Future<void> _open(Uri uri) async {
    final opened = await ref.read(linkLauncherProvider)(uri);
    if (opened || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text("Couldn't open $uri")),
    );
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: widget.color,
      fontSize: 13,
      fontFamily: 'DMSans',
      height: 1.4,
    );
    final link = base.copyWith(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: widget.color,
    );
    return Text.rich(
      key: const ValueKey('terms-consent'),
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(text: 'Terms', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
