import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// "Your profile is private", with a one-tap way out: every profile that
/// existed before Feature 4 starts private (the owner's decision of 14
/// Nov), so the person is told plainly, on the Profile tab and in the
/// editor.
class PrivateProfileCard extends ConsumerStatefulWidget {
  const PrivateProfileCard({super.key});

  static const cardKey = ValueKey('private-profile-card');
  static const makePublicKey = ValueKey('private-profile-make-public');

  @override
  ConsumerState<PrivateProfileCard> createState() => _PrivateProfileCardState();
}

class _PrivateProfileCardState extends ConsumerState<PrivateProfileCard> {
  bool _busy = false;

  Future<void> _makePublic() async {
    setState(() => _busy = true);
    try {
      await ref.read(myProfileProvider.notifier).update({'is_private': false});
      if (mounted) {
        showToast(
            context,
            'Your profile is public. Who sees each part is '
            'still yours to choose.');
      }
    } catch (e) {
      if (mounted) {
        showToast(
            context,
            profileEditErrorMessage(e,
                fallback: "Couldn't change that. Try again."),
            icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: PrivateProfileCard.cardKey,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Text('🔒', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your profile is private: only your name, photo and '
                  'headline are visible.',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Make it public and each part shows to whoever you chose for it.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: PrivateProfileCard.makePublicKey,
            onPressed: _busy ? null : _makePublic,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(_busy ? 'Making it public…' : 'Make it public'),
          ),
        ],
      ),
    );
  }
}

/// "Pick a new handle": the person's username can't be a profile's
/// address (`handle_needs_change`). [onPick] takes them to the handle.
class HandleNeedsChangeCard extends StatelessWidget {
  const HandleNeedsChangeCard({super.key, required this.onPick});

  final VoidCallback onPick;

  static const cardKey = ValueKey('handle-needs-change-card');

  @override
  Widget build(BuildContext context) {
    return Material(
      key: cardKey,
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPick,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Text('✏️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pick a new handle',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text(
                      "Your current one can't be used for a profile link. "
                      'Choose the name for myotherapp.in/u/…',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
