import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  final List<InterestItem> _selectedInterests = [];

  final Map<String, List<InterestItem>> interests = {
    'Academic': [
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
    ],
    'Creative': [
      InterestItem(name: 'Photography', icon: '📸'),
      InterestItem(name: 'Music', icon: '🎵'),
      InterestItem(name: 'Film', icon: '🎬'),
      InterestItem(name: 'Animation', icon: '🐰'),
      InterestItem(name: 'Writing', icon: '✏️'),
      InterestItem(name: 'Fashion', icon: '👗'),
      InterestItem(name: 'Gaming', icon: '🎮'),
    ],
    'Emerging Trends': [
      InterestItem(name: 'Blockchain', icon: '🔗'),
      InterestItem(name: 'VR/AR', icon: '🥽'),
      InterestItem(name: 'Memes & Internet Culture', icon: '🎭'),
      InterestItem(name: 'Content Creation', icon: '🎥'),
      InterestItem(name: 'E-Sports', icon: '🎮'),
      InterestItem(name: 'Space Exploration', icon: '🚀'),
    ],
  };

  Widget _buildInterestChip(InterestItem interest) {
    final isSelected = _selectedInterests.contains(InterestItem(name: interest.name, icon: interest.icon));
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInterests.remove(InterestItem(name: interest.name, icon: interest.icon));
          } else if (_selectedInterests.length < 5) {
            _selectedInterests.add(InterestItem(name: interest.name, icon: interest.icon));
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
            side: BorderSide(
              color: !isSelected ? Colors.transparent : Color(0xFF17A58F),
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              interest.icon,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    final List<dynamic> currentIntrests =
        context.watch<AppBloc>().state.profile?.profile?.interests ?? [];

    for (var interest in currentIntrests) {
      _selectedInterests.add(InterestItem(name: interest.name, icon: interest.icon));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Color(0xFF2C333D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'INTERESTS',
          style: TextStyle(
            color: Color(0xFF2C333D),
            fontSize: 24,
            fontFamily: 'BebasNeue',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 24),
                      ...interests.entries.map((category) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.key,
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
                              children: category.value
                                  .map((interest) =>
                                      _buildInterestChip(interest))
                                  .toList(),
                            ),
                            const SizedBox(height: 36),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _selectedInterests.length > 0
                    ? () {
                        // Handle continue
                        Navigator.pop(context, _selectedInterests.toList());
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2C333D),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CONTINUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'BebasNeue',
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
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
