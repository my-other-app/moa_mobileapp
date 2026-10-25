import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/clubs/domain/club_updates.dart';

/// "Get updates from `<club>` on WhatsApp" under FOLLOW, for a club that
/// offers it. Before following, ticking it makes it go with the follow;
/// once following, it is the follower's own switch, saved at once. The
/// number is the one on their profile.
class ClubUpdatesTile extends StatelessWidget {
  final String clubName;

  /// Whether the box shows ticked.
  final bool value;

  /// Whether they follow the club already (it is then their switch).
  final bool following;

  /// False while a change is on its way.
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const ClubUpdatesTile({
    super.key,
    required this.clubName,
    required this.value,
    required this.following,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: const ValueKey('club-updates-whatsapp'),
      value: value,
      onChanged: enabled ? (v) => onChanged(v ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.ink,
      title: Text(
        clubUpdatesText(clubName),
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'DMSans',
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        following
            ? 'On the mobile number in your profile. Untick to stop them.'
            : 'Comes with the follow, on the mobile number in your profile.',
        style: const TextStyle(fontSize: 13, fontFamily: 'DMSans'),
      ),
    );
  }
}
