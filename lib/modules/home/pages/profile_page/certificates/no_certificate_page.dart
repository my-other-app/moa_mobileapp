import 'package:flutter/material.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';

class NoCertificatePage extends StatelessWidget {
  const NoCertificatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 40,
            ),
            Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.height / 4,
                child: Image(image: AssetImage(AssetResources.nocertificate)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SizedBox(
                child: Text(
                  'You haven’t earned any certificates yet. Participate in an event to earn certificate.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
