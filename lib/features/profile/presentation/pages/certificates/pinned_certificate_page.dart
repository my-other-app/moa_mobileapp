import 'package:flutter/material.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_list_view.dart';

class PinnedCertificatePage extends StatelessWidget {
  const PinnedCertificatePage({super.key});

  @override
  Widget build(BuildContext context) =>
      const CertificateListView(pinnedOnly: true);
}
