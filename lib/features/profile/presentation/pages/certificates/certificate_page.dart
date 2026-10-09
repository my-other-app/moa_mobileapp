import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/profile/presentation/pages/certificates/all_certificate_page.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/pinned_certificate_page.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:finnet/shared/widgets/certificate_tab_header.dart';

class CertificatePage extends ConsumerWidget {
  const CertificatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        CertificateTabHeader(
          tabTitles: const ['PINNED', 'ALL CERTIFICATES'],
          tabPages: const [PinnedCertificatePage(), AllCertificatePage()],
          searchDelegate: CertificateSearchDelegate(ref),
        ),
        // Floating, as in the design. Positioned rather than a
        // floatingActionButton because the tab header owns the Scaffold.
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(child: _SortButton()),
        ),
      ],
    );
  }
}

class _SortButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(certificateSortProvider);

    return Material(
      color: const Color(0xFF2C333D),
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final chosen = await showModalBottomSheet<CertificateSort>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'SORT BY',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'BebasNeue',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final option in CertificateSort.values)
                    ListTile(
                      title: Text(option.label),
                      trailing: option == current
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
          if (chosen != null) {
            ref.read(certificateSortProvider.notifier).state = chosen;
          }
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'SORT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'BebasNeue',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search over the certificate list.
///
/// Writes the query to [certificateSearchProvider] so both tabs filter
/// together, rather than each keeping its own idea of what was typed.
class CertificateSearchDelegate extends SearchDelegate<void> {
  final WidgetRef _ref;

  CertificateSearchDelegate(this._ref)
      : super(searchFieldLabel: 'Search for Certificates');

  void _apply() => _ref.read(certificateSearchProvider.notifier).state = query;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              query = '';
              _apply();
            },
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          // The query stays applied on the way out, so the list behind
          // reflects what was searched for.
          _apply();
          close(context, null);
        },
      );

  @override
  Widget buildResults(BuildContext context) {
    _apply();
    close(context, null);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _apply();
    return const AllCertificatePage();
  }
}
