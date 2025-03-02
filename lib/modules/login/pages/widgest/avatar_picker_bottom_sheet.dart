import 'package:flutter/material.dart';

class Avatar {
  final int id;
  final String url;

  Avatar({required this.id, required this.url});
}

class AvatarPickerBottomSheet extends StatelessWidget {
  const AvatarPickerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // https://picsum.photos/200
    final List<Avatar> avatars = List.generate(
      (12),
      (index) => Avatar(
          id: index + 1,
          url:
              "https://mulearn-backend-test.s3.amazonaws.com/myotherapp-dev/avatars/7d1bedcc-32e3-47e8-8a17-705cfa36544a.png?AWSAccessKeyId=AKIAVS6FAG7XBZZSLLCS&Signature=9Z5uBF9drvJJSUPBT8lwUs%2FeJ%2Fk%3D&Expires=1740899095"),
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      width: double.infinity,
      child: SafeArea(
        child: Column(
          children: [
            Text("Choose a profile picture", style: textTheme.headlineSmall),
            SizedBox(height: 30),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 30,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () {
                    // Handle avatar selection
                  },
                  child: Image.network(
                    avatars[index].url,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            FilledButton(
              onPressed: () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text("Continue")],
              ),
            )
          ],
        ),
      ),
    );
  }
}
