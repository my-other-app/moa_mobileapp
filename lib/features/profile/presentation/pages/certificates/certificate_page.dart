import 'package:flutter/material.dart';
import 'package:myotherapp/features/profile/presentation/pages/certificates/all_certificate_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/certificates/pinned_certificate_page.dart';
import 'package:myotherapp/shared/widgets/certificate_tab_header.dart';

class CertificatePage extends StatelessWidget {
  const CertificatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CertificateTabHeader(
        tabTitles: ["PINNED", "ALL CERTIFICATES"],
        tabPages: [PinnedCertificatePage(), AllCertificatePage()]);
  }
}
