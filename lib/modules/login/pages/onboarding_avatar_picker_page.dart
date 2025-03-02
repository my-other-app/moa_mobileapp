import 'package:flutter/material.dart';
import 'package:myotherapp/modules/login/pages/widgest/avatar_picker_bottom_sheet.dart';

Widget _buildDragIndicator() {
  return Row(
    children: [
      Expanded(
        child: Container(
          height: 4,
          decoration: ShapeDecoration(
            color: const Color(0xFF17A58F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 4,
          decoration: ShapeDecoration(
            color: const Color(0xFF17A58F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 4,
          decoration: ShapeDecoration(
            color: const Color(0xFF17A58F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildProfileImage() {
  // Use a NetworkImage if profileImageUrl is available, otherwise fallback to a placeholder asset.
  return Container(
    width: 150,
    height: 150,
    decoration: ShapeDecoration(
      // image: DecorationImage(
      //   image: profileImageUrl != null
      //       ? NetworkImage(profileImageUrl!)
      //       : const AssetImage('assets/images/profile_placeholder.png')
      //           as ImageProvider,
      //   fit: BoxFit.cover,
      // ),
      color: const Color(0xFFCCC1F0),
      shape: const OvalBorder(),
    ),
  );
}

class OnboardingAvatarPickerPage extends StatefulWidget {
  const OnboardingAvatarPickerPage({super.key});

  @override
  _OnboardingAvatarPickerPageState createState() =>
      _OnboardingAvatarPickerPageState();
}

class _OnboardingAvatarPickerPageState
    extends State<OnboardingAvatarPickerPage> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      appBar: AppBar(
        title: _buildDragIndicator(),
        backgroundColor: const Color(0xFFFFFFA0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 32),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Time to flex with your profile pic",
              style: textTheme.headlineSmall,
            ),
            Text("Choose your profile pic", style: textTheme.bodyMedium),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProfileImage(),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                          context: context,
                          builder: (_) => AvatarPickerBottomSheet());
                    },
                    child: Text(
                      "Tap to choose",
                      style: textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                ],
              ),
            ),
            Spacer(),
            FilledButton(
              onPressed: () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("START THE JOURNEY"),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 28),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
