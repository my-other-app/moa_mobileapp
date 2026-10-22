import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// The signed-in person's picture, in a circle [size] across: wherever the
/// app shows them their own face -- the Profile header, "Change Avatar" in
/// Settings, the picker. All of them read [profileProvider], so a change
/// shows everywhere in the same frame.
///
/// - A photo just taken or chosen is drawn from the phone while it uploads
///   (dimmed, with a spinner), and under the uploaded copy while that
///   loads, so it never blinks back to the old picture.
/// - Then the uploaded photo (the private picture cache), else the picked
///   avatar (the public one), else a person on purple.
class MyPicture extends ConsumerWidget {
  const MyPicture({super.key, this.size = 60});

  final double size;

  static const uploadingKey = ValueKey('my-picture-uploading');
  static const localKey = ValueKey('my-picture-local');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final profile = state.profile;
    final local = state.localPhoto;
    final small = size <= 64;
    final photo = profile?.photo?.urlFor(small: small);
    final avatar = profile?.avatar?.image.urlFor(small: small);

    Widget fallback(BuildContext _) => ColoredBox(
          color: Colors.purple.shade500,
          child: Center(
            child: Icon(Icons.person, size: size / 2, color: Colors.white),
          ),
        );

    Widget localImage(BuildContext context) => Image.file(
          File(local!),
          key: localKey,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          errorBuilder: (context, _, __) => fallback(context),
        );

    final Widget picture;
    if (local != null && (state.uploadingPhoto || photo == null)) {
      picture = localImage(context);
    } else if (photo != null) {
      picture = AppNetworkImage(
        key: ValueKey(imageCacheKey(photo)),
        url: photo,
        width: size,
        height: size,
        privacy: ImagePrivacy.private,
        placeholder: local != null ? localImage : fallback,
        errorWidget: fallback,
      );
    } else if (avatar != null) {
      picture = AppNetworkImage(
        key: ValueKey(imageCacheKey(avatar)),
        url: avatar,
        width: size,
        height: size,
        placeholder: fallback,
        errorWidget: fallback,
      );
    } else {
      picture = fallback(context);
    }

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (state.uploadingPhoto)
              ColoredBox(
                key: uploadingKey,
                color: Colors.black26,
                child: Center(
                  child: SizedBox.square(
                    dimension: size / 3,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
