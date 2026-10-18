import 'package:flutter/material.dart';

import '../../../../core/resources/asset_resources.dart';

class NoClubsFollowingPage extends StatelessWidget {
  const NoClubsFollowingPage({super.key});

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
                child:
                    Image(image: AssetImage(AssetResources.noclubsfollowing)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              child: Center(
                child: Text(
                  'You are not following any clubs, checkout clubs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'DMSans',
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
