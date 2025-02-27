import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_final_page.dart';

class InterestsSelectionPage extends StatefulWidget {
  const InterestsSelectionPage({super.key});

  @override
  State<InterestsSelectionPage> createState() => _InterestsSelectionPageState();
}

class _InterestsSelectionPageState extends State<InterestsSelectionPage> {
  final Set<InterestItem> selectedInterests = {};
  bool isLoading = false;
  final Dio dio = Dio();

  Future<void> _submitInterests() async {
    // Retrieve access token from AppBloc state.
    final accessToken = context.read<AppBloc>().state.accessToken;
    // Extract selected interest IDs
    List<int> interestIds = selectedInterests.map((item) => item.id).toList();
    final url =
        'https://api.staging.myotherapp.com/api/v1/user/interests/select';

    setState(() {
      isLoading = true;
    });

    try {
      final response = await dio.post(
        url,
        data: jsonEncode({'interest_ids': interestIds}),
        options: Options(
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            // Include the access token in your headers if needed. For example:
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        // Navigate to the OnboardingFinalPage upon success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingFinalPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error submitting interests: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting interests: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: SafeArea(
        child: Column(
          children: [
            _buildDragIndicator(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'SPILL THE TEA ON YOUR VIBES AND INTERESTS',
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 24,
                              fontFamily: 'BebasNeue',
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Choose up to 5 vibes that speak to you',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Interest Sections
                    _buildInterestSection('Academic', academicInterests),
                    const SizedBox(height: 36),
                    _buildInterestSection('Creative', creativeInterests),
                    const SizedBox(height: 36),
                    _buildInterestSection(
                        'Emerging Trends', emergingTrendInterests),
                  ],
                ),
              ),
            ),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDragIndicator() {
    return Container(
      width: 393,
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
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
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestSection(String title, List<InterestItem> interests) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interests
                .map((interest) => _buildInterestChip(interest))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestChip(InterestItem interest) {
    final isSelected = selectedInterests.contains(interest);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedInterests.remove(interest);
          } else if (selectedInterests.length < 5) {
            selectedInterests.add(interest);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
            side: BorderSide(
              color: isSelected ? const Color(0xFF17A58F) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              interest.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 4),
            Text(
              interest.name,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 361,
        height: 56,
        child: ElevatedButton(
          onPressed: selectedInterests.isNotEmpty && !isLoading
              ? _submitInterests
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C333D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 128, vertical: 13),
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'CONTINUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'BebasNeue',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }
}

// Updated InterestItem model with id
class InterestItem {
  final int id;
  final String name;
  final String icon;

  InterestItem({required this.id, required this.name, required this.icon});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterestItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Updated interest lists with ids for each interest
final academicInterests = [
  InterestItem(id: 6, name: 'Coding', icon: '💻'),
  InterestItem(id: 7, name: 'UI/UX', icon: '🎨'),
  InterestItem(id: 8, name: 'Data Science', icon: '📊'),
  InterestItem(id: 9, name: 'Entrepreneurship', icon: '👨‍💼'),
  InterestItem(id: 10, name: 'Marketing', icon: '🏷️'),
  InterestItem(id: 11, name: 'Finance', icon: '💰'),
  InterestItem(id: 2, name: 'AI/ML', icon: '🦾'),
  InterestItem(id: 12, name: 'Analytics', icon: '📈'),
  InterestItem(id: 13, name: 'Cybersecurity', icon: '🔒'),
  InterestItem(id: 14, name: 'Product Management', icon: '🏭'),
];

final creativeInterests = [
  InterestItem(id: 15, name: 'Photography', icon: '📸'),
  InterestItem(id: 16, name: 'Music', icon: '🎵'),
  InterestItem(id: 17, name: 'Film', icon: '🎬'),
  InterestItem(id: 18, name: 'Animation', icon: '🐰'),
  InterestItem(id: 19, name: 'Writing', icon: '✏️'),
  InterestItem(id: 20, name: 'Fashion', icon: '👗'),
  InterestItem(id: 21, name: 'Gaming', icon: '🎮'),
];

final emergingTrendInterests = [
  InterestItem(id: 22, name: 'Blockchain', icon: '🔗'),
  InterestItem(id: 23, name: 'VR/AR', icon: '🥽'),
  InterestItem(id: 24, name: 'Memes & Internet Culture', icon: '🎭'),
  InterestItem(id: 25, name: 'Content Creation', icon: '🎥'),
  InterestItem(id: 26, name: 'E-Sports', icon: '🎮'),
  InterestItem(id: 27, name: 'Space Exploration', icon: '🚀'),
];

// Dummy OnboardingFinalPage widget for navigation after a successful API call
