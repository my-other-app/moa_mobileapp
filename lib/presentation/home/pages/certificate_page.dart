import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/all_certificate_page.dart';
import 'package:myotherapp/presentation/home/pages/pinned_certificate_page.dart';
import 'package:myotherapp/presentation/home/widget/certificate_tab_header.dart';

class CertificatePage extends StatelessWidget {
  const CertificatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CertificateTabHeader(
        tabTitles: ["PINNED", "ALL CERTIFICATES"],
        tabPages: [PinnedCertificatePage(), AllCertificatePage()]);
  }
}
