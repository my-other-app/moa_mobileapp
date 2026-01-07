import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/common/widgets/custom_option_tile.dart';
import 'package:myotherapp/core/blocs/app_bloc/app_bloc_bloc.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_bloc.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_event.dart';
import 'package:myotherapp/modules/login/pages/onboarding_initial_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/certificates/certificate_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/edit_profile/edit_profile_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/badges/my_badges_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/notifications/notifications_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/settings/settings_page.dart';

import '../../../../core/resources/asset_resources.dart';

/// Profile Page - migrated to Riverpod with exact same UI.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Menu items - same as legacy
    final menuItems = [
      {
        'label': 'Edit Profile',
        'icon': AssetResources.editprofile,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfilePage()),
          );
        },
      },
      {
        'label': 'My Certificates',
        'icon': AssetResources.mycertificates,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CertificatePage()),
          );
        },
      },
      {
        'label': 'My Badges',
        'icon': AssetResources.mybadges,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyBadgesPage()),
          );
        },
      },
      {
        'label': 'Notifications',
        'icon': AssetResources.notifications,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsNewPage()),
          );
        },
      },
      {
        'label': 'Settings',
        'icon': AssetResources.settings,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
      },
      {
        'label': 'Log Out',
        'icon': AssetResources.logout,
        'onTap': (BuildContext context) {
          _showLogoutDialog(context);
        },
      },
    ];

    // Wrap in ProviderScope for Riverpod access
    return ProviderScope(
      child: BlocBuilder<AppBloc, AppBlocState>(
        buildWhen: (previous, current) {
          return current.profile != previous.profile ||
              current is UpdateUserDetailsState;
        },
        builder: (context, state) {
          final tags = state.profile?.interests ?? [];
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // 1) Avatar, Name, College
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.purple.shade500,
                          child: Image.network(
                            state.profile?.profile?.avatar?.image.original ??
                                'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person,
                                    size: 30, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.profile?.profile?.fullName ?? 'User',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontFamily: 'BebasNeue',
                                ),
                              ),
                              Text(
                                state.profile?.profile?.org?.name ?? '',
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
                                      tag.name ?? '',
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
                                final onTapFunc = item['onTap'] as void
                                    Function(BuildContext);
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
        },
      ),
    );
  }

  static void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  context.read<AppBloc>().add(const LoggedOutEvent());
                  context
                      .read<BottomNavigatorBloc>()
                      .add(UpdateIndexEvent(index: 0));

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => OnboardingInitialPage(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
