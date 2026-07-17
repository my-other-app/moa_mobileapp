import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/auth/data/models/profile.dart';

/// Avatar Picker Bottom Sheet - migrated to Riverpod.
class AvatarPickerBottomSheet extends ConsumerWidget {
  const AvatarPickerBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

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
                      // Reload profile using Riverpod
                      await ref.read(profileProvider.notifier).loadProfile();

                      if (context.mounted) {
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
