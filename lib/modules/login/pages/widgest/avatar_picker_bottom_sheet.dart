import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/blocs/app_bloc/app_bloc_bloc.dart';
import 'package:myotherapp/modules/login/data/models/profile.dart';

class AvatarPickerBottomSheet extends StatelessWidget {
  const AvatarPickerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // https://picsum.photos/200
    // final List<Avatar> avatars = [];

    ValueNotifier<List<Avatar>> avatarsNotifier = ValueNotifier([]);

    ValueNotifier<Avatar?> selectedAvatarNotifier = ValueNotifier(null);

    fetchAvatars() async {
      try {
        final response = await APIService.instance
            .request('/user/avatar/list', DioMethod.get);
        final List data = response.data;
        if (response.statusCode == 200) {
          avatarsNotifier.value =
              data.map((json) => Avatar.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Error fetching avatars: $e');
      }
    }

    fetchAvatars();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      width: double.infinity,
      child: SafeArea(
        child: Column(
          children: [
            Text("Choose a profile picture", style: textTheme.headlineSmall),
            SizedBox(height: 30),
            Expanded(
              child: ValueListenableBuilder(
                  valueListenable: avatarsNotifier,
                  builder: (context, avatars, child) {
                    if (avatars.isEmpty) {
                      //TODO: Show shimmer when avatars are loading
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ValueListenableBuilder(
                        valueListenable: selectedAvatarNotifier,
                        builder: (context, selectedAvatar, child) {
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 30,
                            ),
                            itemCount: avatars.length,
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () {
                                selectedAvatarNotifier.value = avatars[index];
                              },
                              child: CachedNetworkImage(
                                imageUrl: avatars[index].image.thumbnail,
                                imageBuilder: (context, imageProvider) =>
                                    Container(
                                  decoration: BoxDecoration(
                                    border: avatars[index] == selectedAvatar
                                        ? Border.all(
                                            color: Colors.green, width: 3)
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.error),
                                progressIndicatorBuilder:
                                    (context, url, downloadProgress) =>
                                        CircularProgressIndicator(
                                            value: downloadProgress.progress),
                              ),
                              // child: Image.network(
                              //   avatars[index].image.thumbnail,
                              //   fit: BoxFit.fill,
                              // ),
                            ),
                          );
                        });
                  }),
            ),
            SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                if (selectedAvatarNotifier.value != null) {
                  try {
                    final response = await APIService.instance.request(
                      '/user/avatar/select',
                      DioMethod.post,
                      param: {
                        'avatar_id': selectedAvatarNotifier.value?.id,
                      },
                    );
                    if (response.statusCode == 200 && context.mounted) {
                      // Profile? currentProfile =
                      //     context.read<AppBloc>().state.profile;
                          //TODO : to check why profile is null for new user at this point
                           Profile? currentProfile;
                          // context.read<AppBloc>().state.profile;

                      // if (currentProfile == null ||
                      //     currentProfile.profile == null) {
                        final profileRes = await APIService.instance.request(
                          '/user/profile/me',
                          DioMethod.get,
                        );

                        if (profileRes.data != null &&
                            profileRes.statusCode == 200) {
                          Profile updatedProfile =
                              Profile.fromJson(profileRes.data);

                          debugPrint('Updated profile: $updatedProfile');

                          currentProfile = updatedProfile;
                        }
                      // }

                    if (context.mounted) {
                      currentProfile?.profile?.avatar =
                          selectedAvatarNotifier.value!;
                      context
                          .read<AppBloc>()
                          .add(UpdateUserDetailsEvent(profile: currentProfile));
                    
                      Navigator.pop(context);
                    }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'An error occurred during updating avatar.')),
                      );
                    }

                    debugPrint('Error selecting avatar: $e');
                  }
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text("Continue")],
              ),
            )
          ],
        ),
      ),
    );
  }
}
