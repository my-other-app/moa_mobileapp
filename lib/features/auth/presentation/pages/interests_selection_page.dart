import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart'
    hide ProfileState;
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_interest_picker.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// The most interests a person picks.
const maxInterests = 5;

/// Choosing interests: in onboarding, and from Edit Profile.
///
/// The interests come from `/interests/list`, grouped by topic in the
/// shared [TopicInterestPicker]. They used to be three lists written into
/// this file with ids that had to match the server's by hand.
class InterestsSelectionPage extends ConsumerStatefulWidget {
  const InterestsSelectionPage({super.key, required this.isOnboarding});

  final bool isOnboarding;

  @override
  ConsumerState<InterestsSelectionPage> createState() =>
      _InterestsSelectionPageState();
}

class _InterestsSelectionPageState
    extends ConsumerState<InterestsSelectionPage> {
  /// Chosen interest ids, in the order they were chosen.
  final Set<int> _selected = {};

  /// Whether the person has changed anything: until then, a profile that
  /// arrives late still fills in what they had.
  bool _touched = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seed(ref.read(profileProvider).profile);
      ref.listenManual(profileProvider, (_, next) => _seed(next.profile));
    });
  }

  void _seed(UserProfile? profile) {
    if (_touched || profile == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(profile.interests.map((i) => i.id));
    });
  }

  void _toggle(Interest interest) {
    setState(() {
      _touched = true;
      if (!_selected.remove(interest.id)) _selected.add(interest.id);
    });
  }

  void _limitReached() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('You can choose up to $maxInterests interests. '
            'Deselect one to pick another.'),
      ));
  }

  Future<void> _submitInterests() async {
    final interestIds = _selected.toList();

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

      if (mounted) {
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          if (mounted) {
            await ref.read(profileProvider.notifier).loadProfile(force: true);
          }

          if (widget.isOnboarding && mounted) {
            context.go(
                withSignInFrom('/onboarding/avatar', signInFromOf(context)));
          } else if (mounted) {
            context.pop();
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
          SnackBar(
              content: Text(extractErrorMessage(e,
                  defaultMessage: 'Failed to save interests'))),
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
    final catalogue = ref.watch(topicCatalogueProvider);

    return Scaffold(
      backgroundColor:
          widget.isOnboarding ? const Color(0xFFFFFFA0) : Colors.white,
      appBar: widget.isOnboarding
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              scrolledUnderElevation: 0,
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The headline and the ask.
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SPILL THE TEA ON YOUR VIBES AND INTERESTS',
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 28,
                              height: 1.05,
                              fontFamily: 'BebasNeue',
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Choose up to $maxInterests vibes that speak to you',
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 15,
                              fontFamily: 'DMSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                    catalogue.when(
                      data: (topics) => TopicInterestPicker(
                        topics: topics,
                        selectedIds: _selected,
                        maxSelected: maxInterests,
                        onToggle: _toggle,
                        onLimitReached: _limitReached,
                        // White chips on the yellow of onboarding.
                        idleColor:
                            widget.isOnboarding ? Colors.white : null,
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: ErrorView(
                          message: 'Could not load interests.',
                          compact: true,
                          onRetry: () => ref.invalidate(topicCatalogueProvider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

  /// CONTINUE, the full width, held at the bottom; faded until something
  /// is chosen.
  Widget _buildContinueButton() {
    const ink = Color(0xFF2C333D);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          key: const ValueKey('interests-continue'),
          onPressed: _selected.isNotEmpty && !isLoading
              ? _submitInterests
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ink.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
