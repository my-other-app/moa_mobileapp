import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The certificate itself, rendered from the PDF the download produces.
///
/// A hand-drawn preview was close but not the same artifact: the real
/// template carries logos, a QR code, signatories, custom body and footer
/// text, and positioned layers a club can place freely. Reimplementing that
/// in Flutter would drift the moment someone edited a template, and the
/// preview and the download would disagree again.
///
/// WKWebView renders PDFs natively, so pointing one at the PDF endpoint
/// shows exactly what downloading gives you -- the preview cannot drift
/// from the download because it is the download.
class CertificatePdfView extends StatefulWidget {
  final String pdfUrl;

  /// Shown while the PDF loads and if it fails.
  final Widget placeholder;

  const CertificatePdfView({
    super.key,
    required this.pdfUrl,
    required this.placeholder,
  });

  @override
  State<CertificatePdfView> createState() => _CertificatePdfViewState();
}

class _CertificatePdfViewState extends State<CertificatePdfView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      // The PDF sits on a transparent page; the panel behind supplies the
      // colour, as in the design.
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            // A failed load falls back to the drawn preview rather than
            // leaving an empty panel.
            if (mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.pdfUrl));
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.placeholder;

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) widget.placeholder,
      ],
    );
  }
}
