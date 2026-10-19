import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/domain/entities/certificate_style.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_preview.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// One certificate, to the design: preview, title, id, club, two facts,
/// a pin action, the status banner and the download button.
class CertificateDetailPage extends ConsumerWidget {
  final Certificate certificate;

  const CertificateDetailPage({super.key, required this.certificate});

  static const _ink = Color(0xFF1E1E1E);
  static const _preview = Color(0xFFF5C44C);
  static const _banner = Color(0xFFF7F6A8);

  /// The PDF, kept on the phone and fetched again only when the server's
  /// ETag says it changed (a new design, a corrected name, a revocation),
  /// opened in the system's viewer -- which can save and share it, and
  /// works offline from the kept copy. Without a viewer, or without the
  /// PDF, the browser as before.
  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdf = await DocumentCache.instance.fetch(
        '/events/certificates/${certificate.ticketId}/pdf',
        name: 'certificate_${DocumentCache.safeName(certificate.ticketId)}.pdf',
      );
      if (!pdf.current) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Offline — this is your saved copy')));
      }
      final opened = await OpenFilex.open(pdf.file.path);
      if (opened.type == ResultType.done) return;
    } catch (e) {
      debugPrint('Certificate PDF unavailable, opening the link: $e');
    }
    // externalApplication: a PDF belongs in the browser or a viewer, not an
    // in-app webview that cannot save it.
    var launched = false;
    try {
      launched = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!launched) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the certificate')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(pinnedCertificatesProvider);
    final style = ref.watch(certificateStyleProvider(certificate.ticketId));
    // The profile loads itself, so the name is here without this screen
    // having to ask for it.
    final recipient = ref.watch(profileProvider).profile?.fullName;
    // Held while the rendered certificate loads, and used if it cannot be
    // rendered at all, so the panel keeps its shape either way.
    final placeholder = CertificatePreview(
      certificate: certificate,
      style: style.valueOrNull ?? CertificateStyle.fallback,
      recipientName: recipient,
    );
    final isPinned = pinned.contains(certificate.ticketId);
    final pdfUrl = certificate.pdfUrl(Env.apiBaseUrl);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CERTIFICATE',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: _ink),
            onPressed: () => _open(context, pdfUrl),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _PreviewPanel(
                    background: _preview,
                    child: AspectRatio(
                      // The shape the server crops the certificate to, so it
                      // fills the panel rather than letterboxing inside it.
                      aspectRatio: 800 / 519,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AppNetworkImage(
                          url: certificate.imageUrl(Env.apiBaseUrl),
                          fit: BoxFit.contain,
                          // Carries the person's name: emptied on sign-out.
                          privacy: ImagePrivacy.private,
                          placeholder: (_) => placeholder,
                          // Falls back to the drawn version rather than an
                          // empty panel if the render fails.
                          errorWidget: (_) => placeholder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    certificate.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontFamily: 'BebasNeue',
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Certificate ID: ${certificate.ticketId}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if (certificate.clubName != null) ...[
                    const SizedBox(height: 16),
                    _ClubRow(
                      name: certificate.clubName!,
                      logoUrl: certificate.clubLogoUrl,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _FactCard(
                          emoji: '🗓️',
                          label: 'Issue Date',
                          value: _formatDate(certificate.issuedOn),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FactCard(
                          emoji: '🎤',
                          label: 'Event Type',
                          value:
                              (certificate.eventType ?? 'Event').toUpperCase(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PinRow(
                    isPinned: isPinned,
                    onTap: () => ref
                        .read(pinnedCertificatesProvider.notifier)
                        .toggle(certificate.ticketId),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _banner,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Attended and Certificate Generated',
                      style: TextStyle(fontSize: 13, color: _ink),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _open(context, pdfUrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C333D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'DOWNLOAD CERTIFICATE',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'BebasNeue',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The coloured panel the certificate sits on, as in the design.
class _PreviewPanel extends StatelessWidget {
  final Widget child;
  final Color background;

  const _PreviewPanel({required this.child, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _ClubRow extends StatelessWidget {
  final String name;
  final String? logoUrl;

  const _ClubRow({required this.name, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 28,
            height: 28,
            child: logoUrl == null || logoUrl!.isEmpty
                ? const ColoredBox(color: Color(0xFFEFEFEF))
                : AppNetworkImage(
                    url: logoUrl,
                    width: 28,
                    height: 28,
                    errorWidget: (_) =>
                        const ColoredBox(color: Color(0xFFEFEFEF)),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CertificateDetailPage._ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _FactCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _FactCard({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'BebasNeue',
              fontWeight: FontWeight.bold,
              color: CertificateDetailPage._ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  final bool isPinned;
  final VoidCallback onTap;

  const _PinRow({required this.isPinned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('📌', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Text(
              isPinned ? 'Pinned' : 'Pin It',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: CertificateDetailPage._ink,
              ),
            ),
            const Spacer(),
            if (isPinned)
              const Icon(Icons.check, size: 20, color: Colors.green),
          ],
        ),
      ),
    );
  }
}
