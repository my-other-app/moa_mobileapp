import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// Avatar picker page for onboarding.
///
/// Allows users to select their avatar from a predefined list.
class OnboardingAvatarPage extends ConsumerStatefulWidget {
  final bool isOnboarding;

  const OnboardingAvatarPage({
    super.key,
    this.isOnboarding = true,
  });

  @override
  ConsumerState<OnboardingAvatarPage> createState() =>
      _OnboardingAvatarPageState();
}

class _OnboardingAvatarPageState extends ConsumerState<OnboardingAvatarPage> {
  int? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    // Pre-select current avatar if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider).profile;
      if (profile?.avatar != null) {
        setState(() {
          _selectedAvatarId = profile!.avatar!.id;
        });
      }
    });
  }

  Future<void> _saveAvatar() async {
    if (_selectedAvatarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an avatar')),
      );
      return;
    }

    final success = await ref
        .read(profileProvider.notifier)
        .updateAvatar(_selectedAvatarId!);

    if (success && mounted) {
      if (widget.isOnboarding) {
        context.goNamed('home');
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarsAsync = ref.watch(avatarsProvider);
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
                _buildProgressIndicator(3, 4),
                const SizedBox(height: 32),
              ],

              // Header
              const Text(
                'Choose your avatar',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a1a2e),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick an avatar that represents you',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Selected avatar preview
              Center(
                child: _buildSelectedAvatarPreview(),
              ),
              const SizedBox(height: 32),

              // Avatars grid
              Expanded(
                child: avatarsAsync.when(
                  data: (avatars) => _buildAvatarsGrid(avatars),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Failed to load avatars',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.refresh(avatarsProvider),
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
                  onPressed: profileState.isLoading || _selectedAvatarId == null
                      ? null
                      : _saveAvatar,
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
                      : Text(
                          widget.isOnboarding ? 'Get Started' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Skip button for onboarding
              if (widget.isOnboarding) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => context.goNamed('home'),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
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

  Widget _buildSelectedAvatarPreview() {
    final avatarsAsync = ref.watch(avatarsProvider);

    return avatarsAsync.when(
      data: (avatars) {
        final selectedAvatar = _selectedAvatarId != null
            ? avatars.firstWhere(
                (a) => a.id == _selectedAvatarId,
                orElse: () => avatars.first,
              )
            : null;

        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFCCC1F0),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF17A58F),
              width: 3,
            ),
          ),
          child: selectedAvatar != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: selectedAvatar.image.original,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.person, size: 60),
                  ),
                )
              : const Icon(
                  Icons.person,
                  size: 60,
                  color: Color(0xFF8B7ED8),
                ),
        );
      },
      loading: () => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.error, size: 40),
      ),
    );
  }

  Widget _buildAvatarsGrid(List<Avatar> avatars) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = _selectedAvatarId == avatar.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAvatarId = avatar.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF17A58F) : Colors.transparent,
                width: 3,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFCCC1F0),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatar.image.original,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.person, size: 30),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
