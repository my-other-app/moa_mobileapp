import 'package:flutter/material.dart';
import 'package:myotherapp/features/profile/presentation/pages/certificates/no_certificate_page.dart';

class PinnedCertificatePage extends StatelessWidget {
  const PinnedCertificatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return NoCertificatePage();
    // return ColoredBox(
    //   color: Colors.white,
    //   child: ListView(
    //     padding: const EdgeInsets.all(16),
    //     children: <Widget>[
    //       CertificateListCard(
    //         title: 'Blender Workshop Certificate',
    //         organization: 'IEDC CET',
    //         type: 'Workshop',
    //         date: '29 Jan 2024',
    //         imageUrl:
    //             'https://static.vecteezy.com/system/resources/previews/022/590/539/original/summer-party-poster-design-music-party-flyer-artwork-template-vector.jpg',
    //         onTap: () {
    //           // Handle tap
    //         },
    //       ),
    //       SizedBox(
    //         height: 24,
    //       ),
    //       CertificateListCard(
    //         title: 'Blender Workshop Certificate',
    //         organization: 'IEDC CET',
    //         type: 'Workshop',
    //         date: '29 Jan 2024',
    //         imageUrl:
    //             'https://static.vecteezy.com/system/resources/previews/022/590/539/original/summer-party-poster-design-music-party-flyer-artwork-template-vector.jpg',
    //         onTap: () {
    //           // Handle tap
    //         },
    //       ),
    //       SizedBox(
    //         height: 24,
    //       ),
    //     ],
    //   ),
    // );
  }
}
