import 'package:flutter/material.dart';
import 'package:finnet/core/resources/asset_resources.dart';

class NoPastEventsPage extends StatelessWidget {
  const NoPastEventsPage({super.key});

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
                child: Image(image: AssetImage(AssetResources.noevents)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              child: Text(
                'You are not having any completed events',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
