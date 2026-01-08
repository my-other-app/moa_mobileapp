import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart'
    hide ProfileState;
import 'package:myotherapp/features/auth/data/models/profile.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_avatar_picker_page.dart';

/// Interests Selection Page - migrated to Riverpod.
class InterestsSelectionPage extends ConsumerStatefulWidget {
  const InterestsSelectionPage({super.key, required this.isOnboarding});

  final bool isOnboarding;

  @override
  ConsumerState<InterestsSelectionPage> createState() =>
      _InterestsSelectionPageState();
}

class _InterestsSelectionPageState
    extends ConsumerState<InterestsSelectionPage> {
  final Set<InterestItem> selectedInterests = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get current interests from Riverpod profileProvider
      final profile = ref.read(profileProvider).profile;
      List<Interest>? currentInterests;

      // Map UserProfile interests to legacy Interest model
      if (profile?.interests != null) {
        currentInterests = profile!.interests
            .map((i) => Interest(
                  id: i.id,
                  name: i.name,
                  icon: i.icon,
                  iconType: i.iconType,
                ))
            .toList();
      }

      debugPrint(
          'Current interests: ${currentInterests?.map((e) => e.toJson()).toList()}}');

      currentInterests?.forEach((intrests) => selectedInterests.add(
          InterestItem(
              id: intrests.id, name: intrests.name, icon: intrests.icon)));

      setState(() {
        selectedInterests;
      });
    });
  }

  Future<void> _submitInterests() async {
    List<int> interestIds =
        selectedInterests.map((item) => item.id ?? 0).toList();

    setState(() {
      isLoading = true;
    });

    try {
      final response = await APIService.instance.request(
        '/user/interests/select',
        DioMethod.post,
        param: {
          'interest_ids': interestIds,
        },
      );
      debugPrint('Interest selection response: ${response.data}');

      if (mounted) {
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          if (mounted) {
            // Reload profile using Riverpod provider
            await ref.read(profileProvider.notifier).loadProfile();
            debugPrint('Profile reloaded via Riverpod');
          }

          // Navigate to the OnboardingFinalPage upon success

          if (widget.isOnboarding && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const OnboardingAvatarPickerPage()),
            );
          } else if (mounted) {
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error submitting interests: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting interests: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isOnboarding ? const Color(0xFFFFFFA0) : Colors.white,
      appBar: widget.isOnboarding
          ? null
          : AppBar(
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
            if (widget.isOnboarding) _buildDragIndicator(),
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
              interest.icon ?? '',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 4),
            Text(
              interest.name ?? '',
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
            // padding: const EdgeInsets.symmetric(horizontal: 128, vertical: 13),
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
  final int? id;
  final String? name;
  final String? icon;

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
