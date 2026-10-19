import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/profile/domain/entities/certificate_verification.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';

/// "Verify a certificate": is this MyOtherApp certificate genuine, and
/// still valid? `/verify/certificates`, or `/verify/certificates/{code}` to
/// check one straight away.
///
/// The number printed on it (`CERT-XXXXX-XXXXX`) is typed, or its QR code
/// scanned (`certificate:MOA-...`), or a link to it pasted. Public: works
/// with no account, as anyone handed a certificate needs it to.
class CertificateVerifyPage extends ConsumerStatefulWidget {
  /// A code to check on opening.
  final String initialCode;

  const CertificateVerifyPage({super.key, this.initialCode = ''});

  @override
  ConsumerState<CertificateVerifyPage> createState() =>
      _CertificateVerifyPageState();
}

class _CertificateVerifyPageState extends ConsumerState<CertificateVerifyPage> {
  static const _ink = Color(0xFF2C333D);

  late final TextEditingController _input;

  /// The code being checked, in the server's terms; null before a check.
  String? _code;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialCode);
    _code = certificateCodeFrom(widget.initialCode);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _check([String? raw]) {
    final code = certificateCodeFrom(raw ?? _input.text);
    FocusScope.of(context).unfocus();
    setState(() {
      _inputError = code == null
          ? 'Type the number printed on the certificate, like '
              'CERT-7K3QF-X9PWM.'
          : null;
      _code = code;
    });
    // Checked again even when it is the same code: the answer may have
    // changed (revoked), or the last try failed.
    if (code != null) ref.invalidate(certificateVerificationProvider(code));
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CertificateScanPage()),
    );
    if (scanned == null || !mounted) return;
    _input.text = certificateCodeFrom(scanned) ?? scanned;
    _check(scanned);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'VERIFY A CERTIFICATE',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Check that a MyOtherApp certificate is genuine and still valid. '
            'Type the number printed on it, or scan its QR code.',
            style: TextStyle(fontSize: 15, color: _ink, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('verify-code'),
            controller: _input,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onSubmitted: _check,
            decoration: InputDecoration(
              labelText: 'Certificate number',
              hintText: 'CERT-XXXXX-XXXXX',
              errorText: _inputError,
              prefixIcon: const Icon(Icons.workspace_premium_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('verify-submit'),
                  onPressed: _check,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'VERIFY',
                    style: TextStyle(fontSize: 20, fontFamily: 'BebasNeue'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('verify-scan'),
                  onPressed: _scan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _ink),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    'SCAN QR',
                    style: TextStyle(fontSize: 20, fontFamily: 'BebasNeue'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_code != null) _Result(code: _code!, onRetry: _check),
        ],
      ),
    );
  }
}

/// What the check found, once it has.
class _Result extends ConsumerWidget {
  final String code;
  final VoidCallback onRetry;

  const _Result({required this.code, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answer = ref.watch(certificateVerificationProvider(code));
    return answer.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _Panel(
        key: const ValueKey('verify-result-error'),
        color: const Color(0xFFF3F3F3),
        icon: Icons.wifi_off,
        title: "Couldn't check it",
        lines: [
          extractErrorMessage(
            error,
            defaultMessage: "We couldn't reach MyOtherApp. Try again.",
          ),
        ],
        action: TextButton(onPressed: onRetry, child: const Text('Try again')),
      ),
      data: (check) {
        switch (check.result) {
          case CertificateCheck.valid:
            return _Panel(
              key: const ValueKey('verify-result-valid'),
              color: const Color(0xFFE3F6E8),
              icon: Icons.verified,
              iconColor: const Color(0xFF15803D),
              title: 'Genuine certificate',
              facts: [
                ('Awarded to', check.attendeeName),
                ('For', check.eventName),
                ('Issued by', check.issuer),
                (
                  'Issued on',
                  check.issuedAt == null
                      ? null
                      : DateFormat('d MMM y').format(check.issuedAt!),
                ),
                ('Number', check.number),
              ],
            );
          case CertificateCheck.revoked:
            return const _Panel(
              key: ValueKey('verify-result-revoked'),
              color: Color(0xFFFFF1E6),
              icon: Icons.block,
              iconColor: Color(0xFFC2410C),
              title: 'This certificate was revoked',
              lines: [
                'It was issued on MyOtherApp, but the club that issued it '
                    'has withdrawn it. It is no longer valid.',
              ],
            );
          case CertificateCheck.notFound:
            return _Panel(
              key: const ValueKey('verify-result-not-found'),
              color: const Color(0xFFFDECEC),
              icon: Icons.help_outline,
              iconColor: const Color(0xFFB91C1C),
              title: 'No certificate has this number',
              lines: [
                'We looked for $code. Check the number and try again: it '
                    'looks like CERT-7K3QF-X9PWM.',
              ],
            );
        }
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> lines;
  final List<(String, String?)> facts;
  final Widget? action;

  const _Panel({
    super.key,
    required this.color,
    required this.icon,
    this.iconColor = const Color(0xFF2C333D),
    required this.title,
    this.lines = const [],
    this.facts = const [],
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontFamily: 'BebasNeue',
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
            ],
          ),
          for (final line in lines) ...[
            const SizedBox(height: 8),
            Text(line, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          for (final (label, value) in facts)
            if (value != null && value.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ],
          if (action != null) ...[
            const SizedBox(height: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

/// The camera, until it sees a QR code; pops with what the code says.
class CertificateScanPage extends StatefulWidget {
  const CertificateScanPage({super.key});

  @override
  State<CertificateScanPage> createState() => _CertificateScanPageState();
}

class _CertificateScanPageState extends State<CertificateScanPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      _done = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'SCAN THE QR CODE',
          style: TextStyle(fontSize: 22, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        // The platform's own error text is for developers; this says what
        // to do, including when the camera was refused.
        errorBuilder: (context, error) => _CameraUnavailable(
          denied: error.errorCode == MobileScannerErrorCode.permissionDenied,
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  final bool denied;

  const _CameraUnavailable({required this.denied});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                denied
                    ? "MyOtherApp can't use the camera. Turn on camera access "
                        "for it in your phone's Settings, or type the "
                        'number printed on the certificate instead.'
                    : "The camera isn't available right now. Type the number "
                        'printed on the certificate instead.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('TYPE THE NUMBER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
