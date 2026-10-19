import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/common/widgets/custom_option_tile.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/confirmation_dialog.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

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

    // Menu items - same as legacy
    final menuItems = [
      {
        'label': 'Edit Profile',
        'icon': AssetResources.editprofile,
        'onTap': (BuildContext context) {
          context.push('/profile/edit');
        },
      },
      {
        'label': 'My Certificates',
        'icon': AssetResources.mycertificates,
        'onTap': (BuildContext context) {
          context.push('/profile/certificates');
        },
      },
      // Anyone's certificate: is it genuine, and still valid?
      {
        'label': 'Verify a Certificate',
        'icon': AssetResources.mycertificates,
        'onTap': (BuildContext context) {
          context.push('/verify/certificates');
        },
      },
      // TODO: Temporarily hidden - re-enable when badges feature is complete
      // {
      //   'label': 'My Badges',
      //   'icon': AssetResources.mybadges,
      //   'onTap': (BuildContext context) {
      //     context.push('/profile/badges');
      //   },
      // },
      {
        'label': 'Notifications',
        'icon': AssetResources.notifications,
        'onTap': (BuildContext context) {
          context.push('/profile/notifications');
        },
      },
      {
        'label': 'Settings',
        'icon': AssetResources.settings,
        'onTap': (BuildContext context) {
          context.push('/profile/settings');
        },
      },
      {
        'label': 'Log Out',
        'icon': AssetResources.logout,
        'onTap': (BuildContext context) {
          _showLogoutDialog(context, ref);
        },
      },
    ];

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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 40),
              if (failed)
                ErrorView(
                  key: ProfilePage.failedKey,
                  compact: true,
                  message: profileState.error,
                  onRetry: () =>
                      ref.read(profileProvider.notifier).loadProfile(),
                )
              else
                // 1) Avatar, Name, College
                Row(
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
                                errorWidget: (_) => const Icon(Icons.person,
                                    size: 30, color: Colors.white),
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
                            children: tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(tag.hashCode),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 40),
              // 2) The menu list
              Column(
                children: List.generate(menuItems.length, (index) {
                  final item = menuItems[index];
                  return Column(
                    children: [
                      CustomOptionTile(
                        verticalSpacing: 16,
                        leadingImageName: item['icon'].toString(),
                        title: Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 16),
                        ),
                        onTap: () {
                          final onTapFunc =
                              item['onTap'] as void Function(BuildContext);
                          onTapFunc(context);
                        },
                      ),
                      if (index < menuItems.length - 1)
                        const Divider(height: 0),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    ConfirmationDialog.showLogout(
      context: context,
      onConfirm: () async {
        // Clear profile and auth state using Riverpod
        ref.read(profileProvider.notifier).clearProfile();
        await ref.read(authStateProvider.notifier).logout();
        ref.read(navigationIndexProvider.notifier).state = 0;

        // The router takes them to sign-in once the session is gone; pushing
        // onboarding here as well made the screen flicker.
      },
    );
  }
}
