import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/presentation/home/screen.dart';

class OnboardingFinalPage extends StatefulWidget {
  const OnboardingFinalPage({super.key});

  @override
  State<OnboardingFinalPage> createState() => _OnboardingFinalPageState();
}

class _OnboardingFinalPageState extends State<OnboardingFinalPage> {
  String? profileImageUrl;
  final Dio dio = Dio();

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    // Get the access token from AppBloc
    final accessToken = context.read<AppBloc>().state.accessToken;
    const url = 'https://api.staging.myotherapp.com/api/v1/user/profile/me';

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      // Print full response to the console
      print('User profile response: ${response.data}');

      final data = response.data;
      String? imageUrl;
      // Assume the image URL is found in the avatar image.
      // It may be a string directly or a map containing a "url" key.
      if (data != null &&
          data['profile'] != null &&
          data['profile']['avatar'] != null &&
          data['profile']['avatar']['image'] != null) {
        final avatarImage = data['profile']['avatar']['image'];
        if (avatarImage is Map && avatarImage['url'] != null) {
          imageUrl = avatarImage['url'];
        } else if (avatarImage is String) {
          imageUrl = avatarImage;
        }
      }
      if (mounted) {
        setState(() {
          profileImageUrl = imageUrl;
        });
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      _buildProfileCreatedSection(),
                      const SizedBox(height: 24),
                      _buildProfileImage(),
                      const SizedBox(height: 24),
                      _buildMotivationalText(),
                      const SizedBox(height: 48),
                      _buildStartJourneyButton(context),
                      const SizedBox(height: 80), // bottom padding for grass
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/grass.png',
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    // Use a NetworkImage if profileImageUrl is available, otherwise fallback to a placeholder asset.
    return Container(
      width: 150,
      height: 150,
      decoration: ShapeDecoration(
        image: DecorationImage(
          image: profileImageUrl != null
              ? NetworkImage(profileImageUrl!)
              : const AssetImage('assets/images/profile_placeholder.png')
                  as ImageProvider,
          fit: BoxFit.cover,
        ),
        color: const Color(0xFFCCC1F0),
        shape: const OvalBorder(),
      ),
    );
  }

  Widget _buildProfileCreatedSection() {
    return SizedBox(
      width: 361,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Text(
                'PROFILE CREATED  ✅',
                style: TextStyle(
                  color: Color(0xFF1E1E1E),
                  fontSize: 24,
                  fontFamily: 'BebasNeue',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Your profile's all set, now it's time to dive into the events and level up",
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalText() {
    return SizedBox(
      width: 301,
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          children: [
            TextSpan(
              text: "Life's a ",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text: 'rollercoaster',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: ', and setbacks are just bumps along the ride. ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text: 'Success takes time',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: ", so don't rush—",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text: 'trust the process',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: " and stay patient. 💫🌱\n\n'",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text:
                  "Success isn't a sprint, it's a vibe. Keep going, it'll click",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: ".' ",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartJourneyButton(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFF2C333D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LandingPage()),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 13),
            child: Row(
              children: const [
                Text(
                  'START THE JOURNEY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'BebasNeue',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
