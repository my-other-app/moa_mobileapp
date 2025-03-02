import 'package:flutter/material.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';

import '../../clubs_page/explore_more_clubs_page.dart';

class NoFollowingClubPage extends StatelessWidget {
  const NoFollowingClubPage({super.key});

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
                child: Image(image: AssetImage(AssetResources.nofollowclub)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SizedBox(
                child: Text(
                  'You are not following any clubs. Follow clubs to get events update from clubs',
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExploreMoreClubsPage(),
                      ),
                    );
                  },
                  child: Text('VIEW CLUBS'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
