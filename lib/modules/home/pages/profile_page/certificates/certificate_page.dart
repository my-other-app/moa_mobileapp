import 'package:flutter/material.dart';
import 'package:myotherapp/modules/home/pages/profile_page/certificates/all_certificate_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/certificates/pinned_certificate_page.dart';
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
