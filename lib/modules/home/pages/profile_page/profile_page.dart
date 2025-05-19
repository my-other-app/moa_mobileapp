import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Example tags
    // For each menu item, define a label, icon, and onTap function
    final menuItems = [
      {
        'label': 'Edit Profile',
        'icon': AssetResources.editprofile,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditProfilePage()),
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
            MaterialPageRoute(builder: (_) => SettingsPage()),
          );
        },
      },
      {
        'label': 'Log Out',
        'icon': AssetResources.logout,
        'onTap': (BuildContext context) {
          // Show confirmation dialog
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
                      // Close the dialog
                      Navigator.of(dialogContext).pop();
                      // Dispatch logout event to AppBloc
                      if (context.mounted) {
                        context.read<AppBloc>().add(const LoggedOutEvent());
                        context
                            .read<BottomNavigatorBloc>()
                            .add(UpdateIndexEvent(index: 0));

                        // Navigate to login page and clear navigation stack
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
        },
      },
    ];
    // Add a BlocListener to verify state changes are being received
    return BlocListener<AppBloc, AppBlocState>(
      listener: (context, state) {
        debugPrint(
            '🔔 ProfilePage - BlocListener received state: ${state.runtimeType}');
        debugPrint('🔔 Profile in state: ${state.profile?.fullName}');
      },
      listenWhen: (previous, current) => true, // Listen to all state changes
      child: BlocBuilder<AppBloc, AppBlocState>(
        buildWhen: (previous, current) {
          // Add debug prints to verify if buildWhen is being called
          debugPrint('ProfilePage - buildWhen called');
          debugPrint(
              'Previous state: ${previous.runtimeType}, Current state: ${current.runtimeType}');
          debugPrint(
              'Previous profile: ${previous.profile}, Current profile: ${current.profile}');

          // Ensure we rebuild when profile changes, including after UpdateUserDetailsEvent
          final shouldRebuild = current.profile != previous.profile ||
              current is UpdateUserDetailsState;
          debugPrint('Should rebuild: $shouldRebuild');
          return shouldRebuild;
        },
        builder: (context, state) {
          final tags = state.profile?.interests ?? [];
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  spacing: 40, // If you're using a package like spaced_column
                  children: [
                    // 1) Avatar, Name, College
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16, // If you're using spaced_row or similar
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.purple.shade500,
                          child: Image.network(
                            state.profile?.profile?.avatar?.image.original ??
                                'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            spacing: 24, // If using spaced_column
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    state.profile?.profile?.fullName ?? 'User',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontFamily: 'BebasNeue',
                                    ),
                                  ),
                                  Text(
                                    state.profile?.profile?.org?.name ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'BebasNeue',
                                    ),
                                  ),
                                ],
                              ),
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
                                      '${tag.name}',
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
                                // Call the function we stored in 'onTap'
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
}
