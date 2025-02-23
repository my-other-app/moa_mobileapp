import 'package:flutter/material.dart';

class InterestsSelectionPage extends StatefulWidget {
  const InterestsSelectionPage({super.key});

  @override
  State<InterestsSelectionPage> createState() => _InterestsSelectionPageState();
}

class _InterestsSelectionPageState extends State<InterestsSelectionPage> {
  final Set<String> selectedInterests = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFFFA0),
      body: SafeArea(
        child: Column(
          children: [
            _buildDragIndicator(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SPILL THE TEA ON YOUR VIBES AND INTERESTS',
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 24,
                              fontFamily: 'BebasNeue',
                            ),
                          ),
                          const SizedBox(height: 8),
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
                color: Color(0xFF17A58F),
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
                color: Color(0xFF17A58F),
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
            style: TextStyle(
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
    final isSelected = selectedInterests.contains(interest.name);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedInterests.remove(interest.name);
          } else if (selectedInterests.length < 5) {
            selectedInterests.add(interest.name);
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
              color: isSelected ? Color(0xFF17A58F) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              interest.icon,
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 4),
            Text(
              interest.name,
              style: TextStyle(
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
      child: Container(
        width: 361,
        height: 56,
        child: ElevatedButton(
          onPressed: selectedInterests.isNotEmpty
              ? () {
                  // Navigate to next page
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2C333D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(horizontal: 128, vertical: 13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'CONTINUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'BebasNeue',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class InterestItem {
  final String name;
  final String icon;

  InterestItem({required this.name, required this.icon});
}

final academicInterests = [
  InterestItem(name: 'Coding', icon: '💻'),
  InterestItem(name: 'UI/UX', icon: '🎨'),
  InterestItem(name: 'Data Science', icon: '📊'),
  InterestItem(name: 'Entrepreneurship', icon: '👨‍💼'),
  InterestItem(name: 'Marketing', icon: '🏷️'),
  InterestItem(name: 'Finance', icon: '💰'),
  InterestItem(name: 'AI/ML', icon: '🦾'),
  InterestItem(name: 'Analytics', icon: '📈'),
  InterestItem(name: 'Cybersecurity', icon: '🔒'),
  InterestItem(name: 'Product Management', icon: '🏭'),
];

final creativeInterests = [
  InterestItem(name: 'Photography', icon: '📸'),
  InterestItem(name: 'Music', icon: '🎵'),
  InterestItem(name: 'Film', icon: '🎬'),
  InterestItem(name: 'Animation', icon: '🐰'),
  InterestItem(name: 'Writing', icon: '✏️'),
  InterestItem(name: 'Fashion', icon: '👗'),
  InterestItem(name: 'Gaming', icon: '🎮'),
];

final emergingTrendInterests = [
  InterestItem(name: 'Blockchain', icon: '🔗'),
  InterestItem(name: 'VR/AR', icon: '🥽'),
  InterestItem(name: 'Memes & Internet Culture', icon: '🎭'),
  InterestItem(name: 'Content Creation', icon: '🎥'),
  InterestItem(name: 'E-Sports', icon: '🎮'),
  InterestItem(name: 'Space Exploration', icon: '🚀'),
];
