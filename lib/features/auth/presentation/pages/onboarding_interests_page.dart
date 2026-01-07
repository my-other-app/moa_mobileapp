import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/features/profile/domain/entities/profile_entity.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart';

/// Interests selection page for onboarding.
///
/// Allows users to select their interests from a predefined list.
class OnboardingInterestsPage extends ConsumerStatefulWidget {
  final bool isOnboarding;

  const OnboardingInterestsPage({
    super.key,
    this.isOnboarding = true,
  });

  @override
  ConsumerState<OnboardingInterestsPage> createState() =>
      _OnboardingInterestsPageState();
}

class _OnboardingInterestsPageState
    extends ConsumerState<OnboardingInterestsPage> {
  final Set<int> _selectedInterestIds = {};
  static const int _minInterests = 3;

  @override
  void initState() {
    super.initState();
    // Pre-select existing interests if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider).profile;
      if (profile != null) {
        setState(() {
          _selectedInterestIds.addAll(profile.interests.map((i) => i.id));
        });
      }
    });
  }

  Future<void> _saveInterests() async {
    if (_selectedInterestIds.length < _minInterests) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least $_minInterests interests'),
        ),
      );
      return;
    }

    final success = await ref
        .read(profileProvider.notifier)
        .updateInterests(_selectedInterestIds.toList());

    if (success && mounted) {
      if (widget.isOnboarding) {
        context.goNamed('onboardingAvatar');
      } else {
        context.pop();
      }
    }
  }

  void _toggleInterest(int interestId) {
    setState(() {
      if (_selectedInterestIds.contains(interestId)) {
        _selectedInterestIds.remove(interestId);
      } else {
        _selectedInterestIds.add(interestId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final interestsAsync = ref.watch(interestsProvider);
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              if (widget.isOnboarding) ...[
                _buildProgressIndicator(2, 4),
                const SizedBox(height: 32),
              ],

              // Header
              const Text(
                'What are you interested in?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a1a2e),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select at least $_minInterests interests to personalize your feed',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedInterestIds.length} selected',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _selectedInterestIds.length >= _minInterests
                      ? const Color(0xFF17A58F)
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Interests grid
              Expanded(
                child: interestsAsync.when(
                  data: (interests) => _buildInterestsGrid(interests),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Failed to load interests',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.refresh(interestsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: profileState.isLoading ||
                          _selectedInterestIds.length < _minInterests
                      ? null
                      : _saveInterests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF17A58F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: profileState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (index) {
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < total - 1 ? 8 : 0),
            decoration: BoxDecoration(
              color:
                  index < current ? const Color(0xFF17A58F) : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInterestsGrid(List<Interest> interests) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: interests.length,
      itemBuilder: (context, index) {
        final interest = interests[index];
        final isSelected = _selectedInterestIds.contains(interest.id);

        return GestureDetector(
          onTap: () => _toggleInterest(interest.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF17A58F) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF17A58F) : Colors.grey[300]!,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF17A58F).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  interest.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF1a1a2e),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
