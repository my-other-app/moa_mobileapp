import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/sign_out.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

/// Profile Page - exact same UI as original, using Riverpod for state.
///
/// The menu -- Settings, certificates, notifications, signing out -- is
/// always there: none of it needs the profile to have loaded.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  /// Where the profile would be, when it could not be loaded.
  static const failedKey = ValueKey('profile-failed');

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
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch profile state from Riverpod
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;

    // The menu: rows of the Settings design, as on Settings itself.
    final menu = dividedRows([
      SettingsRow(
        asset: AssetResources.editprofile,
        label: 'Edit Profile',
        onTap: () => context.push('/profile/edit'),
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
      // TODO: Temporarily hidden - re-enable when badges feature is complete
      // SettingsRow(
      //   asset: AssetResources.mybadges,
      //   label: 'My Badges',
      //   onTap: () => context.push('/profile/badges'),
      // ),
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
    final avatarUrl = profile?.avatar?.image.original;

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
                          // Avatar with proper clipping
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.purple.shade500,
                            ),
                            child: ClipOval(
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? AppNetworkImage(
                                      url: avatarUrl,
                                      width: 60,
                                      height: 60,
                                      privacy: ImagePrivacy.private,
                                      errorWidget: (_) => const Icon(
                                          Icons.person,
                                          size: 30,
                                          color: Colors.white),
                                      placeholder: (_) => const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.person,
                                      size: 30, color: Colors.white),
                            ),
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
                                Text(
                                  profile?.organization?.name ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'BebasNeue',
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
