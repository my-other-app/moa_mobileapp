import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart'
    show ProfileCompleteness;
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/widgets/profile_notices.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/sign_out.dart';
import 'package:finnet/features/profile/presentation/widgets/my_picture.dart';
import 'package:finnet/features/speakers/data/speakers_api.dart';
import 'package:finnet/features/speakers/domain/speaker.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

/// Profile Page - exact same UI as original, using Riverpod for state.
///
/// The menu -- Settings, certificates, notifications, signing out -- is
/// always there: none of it needs the profile to have loaded.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  /// Where the profile would be, when it could not be loaded.
  static const failedKey = ValueKey('profile-failed');

  /// The picture in the header. It is changed on Edit Profile.
  static const pictureKey = ValueKey('profile-picture');

  /// Speakers I Follow, in the menu.
  static const followedSpeakersKey = ValueKey('profile-followed-speakers');

  /// My Public Profile and My QR, in the menu.
  static const publicProfileKey = ValueKey('profile-public-profile');
  static const myQrKey = ValueKey('profile-my-qr');

  /// "Make it easy for people you meet to find your work."
  static const nudgeKey = ValueKey('profile-public-nudge');

  /// The ring round the picture: how complete the public profile is.
  static const completenessRingKey = ValueKey('profile-completeness-ring');

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Load profile on page init
    Future.microtask(() {
      ref.read(profileProvider.notifier).loadProfile();
      // The public profile's headline and how complete it is.
      ref.read(myProfileProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch profile state from Riverpod
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    // Hidden only once the server says it has no speakers directory (404):
    // there while the list loads, and when it fails (the page says so).
    final followed = ref.watch(followedSpeakersProvider);
    final speakersShown = !(followed.hasValue && followed.value == null);
    final public = ref.watch(myProfileProvider).profile;

    // The menu: rows of the Settings design, as on Settings itself.
    final menu = dividedRows([
      SettingsRow(
        asset: AssetResources.editprofile,
        label: 'Edit Profile',
        onTap: () => context.push('/profile/edit'),
      ),
      // What people see when they scan the person's QR or open their link.
      SettingsRow(
        key: ProfilePage.publicProfileKey,
        emoji: '🪪',
        label: 'My Public Profile',
        onTap: () => context.push(editPublicProfileLocation),
      ),
      SettingsRow(
        key: ProfilePage.myQrKey,
        emoji: '🔳',
        label: 'My QR',
        onTap: () => context.push(myQrLocation),
      ),
      SettingsRow(
        asset: AssetResources.mycertificates,
        label: 'My Certificates',
        onTap: () => context.push('/profile/certificates'),
      ),
      // Anyone's certificate: is it genuine, and still valid?
      SettingsRow(
        emoji: '🔍',
        label: 'Verify a Certificate',
        onTap: () => context.push('/verify/certificates'),
      ),
      // The badges the server has awarded, and the ones still to earn.
      SettingsRow(
        asset: AssetResources.mybadges,
        label: 'My Badges',
        onTap: () => context.push('/profile/badges'),
      ),
      // The speakers they follow, each opening the speaker's page.
      if (speakersShown)
        SettingsRow(
          key: ProfilePage.followedSpeakersKey,
          emoji: '🎤',
          label: 'Speakers I Follow',
          onTap: () => context.push(followedSpeakersLocation),
        ),
      SettingsRow(
        asset: AssetResources.notifications,
        label: 'Notifications',
        onTap: () => context.push('/profile/notifications'),
      ),
      SettingsRow(
        asset: AssetResources.settings,
        label: 'Settings',
        onTap: () => context.push('/profile/settings'),
      ),
      SettingsRow(
        asset: AssetResources.logout,
        label: 'Log Out',
        onTap: () => confirmSignOut(context, ref),
      ),
    ]);

    final tags = profile?.interests ?? [];

    // The shimmer only while there is nothing to show at all: the profile
    // saved on the phone is drawn at once, and stays while it is refreshed.
    // This screen used to blank itself into the shimmer on every visit until
    // the server answered, and into a full-page error when it could not --
    // and with it went the way to Settings and to signing out, offline or
    // on a weak signal.
    if (profile == null && profileState.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: ShimmerProfileCard()),
      );
    }

    // No profile, saved or fresh: say why where the profile would be, and
    // keep the menu below it. Offline this is the offline state, which
    // loads the profile by itself when the network is back.
    final failed = profile == null && profileState.error != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          // The menu runs to the screen's edges, its dividers with it; the
          // profile above it keeps the gutter.
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: failed
                    ? ErrorView(
                        key: ProfilePage.failedKey,
                        compact: true,
                        message: profileState.error,
                        onRetry: () =>
                            ref.read(profileProvider.notifier).loadProfile(),
                      )
                    // 1) Avatar, Name, College
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Their picture: the photo they uploaded, else
                          // their avatar. Edit Profile changes it. While the
                          // public profile is incomplete, a ring round it
                          // says how far along it is, and a tap finishes it.
                          _PictureWithProgress(
                            score: public?.completeness.score,
                            complete: public?.completeness.complete ?? true,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.fullName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontFamily: 'BebasNeue',
                                  ),
                                ),
                                // No organisation: no empty line under the name.
                                if ((profile?.organization?.name ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    profile!.organization!.name.trim(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'BebasNeue',
                                    ),
                                  ),
                                if (public?.profile.headline != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      public!.profile.headline!,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                // 2) Tags
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final (index, tag) in tags.indexed)
                                      InterestTag(
                                        label: tag.name,
                                        glyph: tag.emoji,
                                        color: InterestTag.pastelAt(index),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              // Every profile from before Feature 4 starts private.
              if (public != null && public.settings.isPrivate)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: PrivateProfileCard(),
                ),
              if (public != null && public.handleNeedsChange)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: HandleNeedsChangeCard(
                    onPick: () => context.push(editPublicProfileLocation),
                  ),
                ),
              if (public != null && !public.completeness.complete)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _PublicProfileNudge(
                    missing: public.completeness.missing,
                    score: public.completeness.score,
                  ),
                ),
              const SizedBox(height: 40),
              // 2) The menu list
              ...menu,
            ],
          ),
        ),
      ),
    );
  }
}

/// "Make it easy for people you meet to find your work": what the public
/// profile still lacks, into its editor.
class _PublicProfileNudge extends StatelessWidget {
  const _PublicProfileNudge({required this.missing, required this.score});

  final List<String> missing;
  final int score;

  @override
  Widget build(BuildContext context) {
    final parts = missing.map(ProfileCompleteness.missingLabel).toList();
    final add = parts.isEmpty
        ? null
        : parts.length == 1
            ? parts.single
            : '${parts.sublist(0, parts.length - 1).join(', ')} and '
                '${parts.last}';
    return Material(
      color: const Color(0xFFF9FFA1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1E1E1E)),
      ),
      child: InkWell(
        key: ProfilePage.nudgeKey,
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: () => context.push(editPublicProfileLocation),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Make it easy for people you meet to find your work',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    if (add != null) ...[
                      const SizedBox(height: 2),
                      Text('Add $add · $score% done',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}


/// The picture, and round it how complete the public profile is: a ring
/// filled to the score, with the percent on a tag at its foot. A tap opens
/// the public profile's editor. A complete profile, or one not read yet,
/// shows the picture alone.
class _PictureWithProgress extends StatelessWidget {
  const _PictureWithProgress({required this.score, required this.complete});

  final int? score;
  final bool complete;

  static const _size = 60.0;
  static const _ring = 4.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    const picture = MyPicture(key: ProfilePage.pictureKey, size: _size);
    final value = score;
    if (value == null || complete) return picture;
    final percent = value.clamp(0, 100);
    const outer = _size + (_ring + _gap) * 2;
    return Semantics(
      button: true,
      label: 'Your public profile is $percent% complete. Tap to finish it.',
      excludeSemantics: true,
      child: GestureDetector(
        key: ProfilePage.completenessRingKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(editPublicProfileLocation),
        child: SizedBox(
          width: outer,
          height: outer + 8,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: outer,
                height: outer,
                child: CustomPaint(
                  painter: _RingPainter(percent / 100, stroke: _ring),
                  child: const Center(child: picture),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FFA1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF1E1E1E)),
                  ),
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
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
}

/// A track and, over it, an arc from the top clockwise to [fraction].
class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction, {required this.stroke});

  final double fraction;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE6E6E6);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1E1E1E);
    canvas.drawOval(inset, track);
    if (fraction > 0) {
      canvas.drawArc(inset, -1.5707963267948966,
          6.283185307179586 * fraction.clamp(0, 1), false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.stroke != stroke;
}
