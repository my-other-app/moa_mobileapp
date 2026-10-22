import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/data/photo_picker.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/widgets/my_picture.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// What was picked in [ChangeAvatarSheet].
sealed class AvatarChoice {
  const AvatarChoice();
}

/// One of the preset avatars.
class PresetAvatarChoice extends AvatarChoice {
  const PresetAvatarChoice(this.avatar);
  final Avatar avatar;
}

/// A photo, from the camera or the library.
class PhotoAvatarChoice extends AvatarChoice {
  const PhotoAvatarChoice(this.source);
  final PhotoSource source;
}

/// "Change Avatar", from Profile and from Settings: the sheet, then the
/// change. The picture changes everywhere the moment something is picked
/// (or, for a photo, the moment it is taken), and goes back with a message
/// if the server refuses.
Future<void> changeAvatar(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final choice = await showModalBottomSheet<AvatarChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const ChangeAvatarSheet(),
  );
  if (choice == null) return;

  final notifier = container.read(profileProvider.notifier);
  String? problem;
  var uploaded = false;
  switch (choice) {
    case PresetAvatarChoice(:final avatar):
      problem = await notifier.chooseAvatar(avatar);
    case PhotoAvatarChoice(:final source):
      String? path;
      try {
        path = await container.read(photoPickerProvider).pick(source);
      } on PhotoPickFailure catch (e) {
        problem = e.message;
      }
      if (path != null) {
        problem = await notifier.uploadPhoto(path);
        uploaded = problem == null;
      }
  }
  if (!context.mounted) return;
  if (problem != null) {
    showToast(context, problem,
        icon: Icons.error_outline, duration: const Duration(seconds: 4));
  } else if (uploaded) {
    showToast(context, 'Your new photo is up.');
  }
}

/// The picker: take or choose a photo, or pick one of the preset avatars
/// (the one in use ticked). Pops with an [AvatarChoice], or null.
///
/// The avatars come from the copy saved on this phone at once, then the
/// server's.
class ChangeAvatarSheet extends ConsumerWidget {
  const ChangeAvatarSheet({super.key});

  static const cameraKey = ValueKey('change-avatar-camera');
  static const libraryKey = ValueKey('change-avatar-library');
  static const retryKey = ValueKey('change-avatar-retry');

  static ValueKey<String> tileKey(int id) => ValueKey('avatar-choice-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    // With a photo up, no avatar is in use: none is ticked.
    final current = profile?.photo == null ? profile?.avatar?.id : null;
    final avatars = ref.watch(avatarsProvider);
    final height = MediaQuery.sizeOf(context).height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'CHANGE AVATAR',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
            ),
            const SizedBox(height: 12),
            const Center(child: MyPicture(size: 84)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PhotoButton(
                    key: cameraKey,
                    icon: Icons.photo_camera_outlined,
                    label: 'Take a photo',
                    onTap: () => Navigator.of(context)
                        .pop(const PhotoAvatarChoice(PhotoSource.camera)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PhotoButton(
                    key: libraryKey,
                    icon: Icons.photo_library_outlined,
                    label: 'Choose a photo',
                    onTap: () => Navigator.of(context)
                        .pop(const PhotoAvatarChoice(PhotoSource.library)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              profile?.photo != null
                  ? 'Or pick an avatar instead of your photo'
                  : 'Or pick an avatar',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: avatars.when(
                skipLoadingOnRefresh: true,
                data: (list) => list.isEmpty
                    ? const _Note('No avatars to pick from yet.')
                    : _AvatarGrid(
                        avatars: list,
                        current: current,
                        onPick: (avatar) => Navigator.of(context)
                            .pop(PresetAvatarChoice(avatar)),
                      ),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Note("Couldn't load the avatars."),
                    TextButton(
                      key: retryKey,
                      onPressed: () => ref.invalidate(avatarsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E1E1E),
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
    required this.avatars,
    required this.current,
    required this.onPick,
  });

  final List<Avatar> avatars;
  final int? current;
  final ValueChanged<Avatar> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final chosen = avatar.id == current;
        return Semantics(
          button: true,
          selected: chosen,
          label: 'Avatar ${index + 1}',
          excludeSemantics: true,
          child: GestureDetector(
            key: ChangeAvatarSheet.tileKey(avatar.id),
            onTap: () => onPick(avatar),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: chosen
                            ? const Color(0xFF17A58F)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: AppNetworkImage(
                        url: avatar.image.urlFor(small: true),
                        decodeWidth: 240,
                        errorWidget: (_) => const ColoredBox(
                          color: Color(0xFFEFEFEF),
                          child: Icon(Icons.face, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                if (chosen)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      key: const ValueKey('avatar-choice-tick'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF17A58F),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check,
                          size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B6B6B)),
        ),
      );
}
