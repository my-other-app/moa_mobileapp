import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/features/profile/presentation/pages/certificates/no_certificate_page.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:finnet/features/profile/domain/entities/certificate_style.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_preview.dart';
import 'package:finnet/shared/widgets/certificate_list_card.dart';

/// The list behind both the ALL and PINNED tabs.
///
/// Both tabs used to return NoCertificatePage() unconditionally, with
/// hardcoded cards commented out beneath, and neither made a request. A
/// user with certificates saw the same empty screen as one without.
class CertificateListView extends ConsumerWidget {
  /// When true, only pinned certificates are shown.
  final bool pinnedOnly;

  const CertificateListView({super.key, this.pinnedOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificatesAsync = ref.watch(certificatesProvider);
    final pinned = ref.watch(pinnedCertificatesProvider);
    final query = ref.watch(certificateSearchProvider);
    final sort = ref.watch(certificateSortProvider);

    return certificatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _CertificatesError(
        onRetry: () => ref.invalidate(certificatesProvider),
      ),
      data: (all) {
        final shown = applyCertificateFilters(
          all,
          query: query,
          sort: sort,
          onlyPinned: pinnedOnly ? pinned : null,
        );

        if (shown.isEmpty) {
          // Three different nothings, and they mean different things: you
          // have none, you have pinned none, or your search matched none.
          if (query.trim().isNotEmpty) {
            return _EmptyMessage(
              icon: Icons.search_off,
              title: 'Nothing matches "${query.trim()}"',
              subtitle: 'Try a different event, club or type.',
            );
          }
          if (pinnedOnly) {
            return const _EmptyMessage(
              icon: Icons.push_pin_outlined,
              title: 'No pinned certificates',
              subtitle: 'Open a certificate and tap Pin It to keep it here.',
            );
          }
          return const NoCertificatePage();
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(certificatesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final certificate = shown[index];
              // A miniature of the certificate itself. Too small to read,
              // but it carries the club's colours, which is what a
              // thumbnail is for.
              final style = ref
                      .watch(certificateStyleProvider(certificate.ticketId))
                      .valueOrNull ??
                  CertificateStyle.fallback;

              return CertificateListCard(
                leading: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 160,
                    child: CertificatePreview(
                      certificate: certificate,
                      style: style,
                    ),
                  ),
                ),
                title: certificate.title,
                organization: certificate.clubName ?? '',
                type: certificate.eventType ?? '',
                date: _formatDate(certificate.issuedOn),
                imageUrl: certificate.thumbnailUrl ?? '',
                onTap: () => context.push(
                  '/profile/certificates/${certificate.ticketId}',
                  extra: {'certificate': certificate},
                ),
              );
            },
          ),
        );
      },
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "29 Jan 2024", as the design shows it.
String _formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificatesError extends StatelessWidget {
  final VoidCallback onRetry;

  const _CertificatesError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Couldn't load certificates",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
