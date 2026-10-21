import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/events/presentation/providers/networking_provider.dart';
import 'package:finnet/shared/widgets/app_toggle.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

/// "Show me in People Like You" in Settings: a row of the Settings design,
/// a line saying what it does, then a divider. Nothing while it is unknown
/// -- or from a server without the switch.
class NetworkingVisibilityRow extends ConsumerWidget {
  const NetworkingVisibilityRow({super.key});

  static const rowKey = ValueKey('privacy-switch-people-like-you');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(networkingVisibilityProvider);
    final visible = state.visible;
    if (visible == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          key: rowKey,
          emoji: '🤝',
          label: 'Show me in People Like You',
          value: visible,
          onChanged: (on) =>
              ref.read(networkingVisibilityProvider.notifier).set(on),
        ),
        SettingsCaption(state.error ??
            'At an event you’re checked in to, people who share your '
                'interests can find you. You can still look when it’s off.',
            color: state.error != null ? Colors.red : null),
        const SettingsDivider(),
      ],
    );
  }
}

/// The same switch at the top of People Like You, said for the room: "You're
/// visible to others here", so it can be turned off on the spot. Nothing
/// while it is unknown.
class NetworkingVisibilityBanner extends ConsumerWidget {
  const NetworkingVisibilityBanner({super.key});

  static const switchKey = ValueKey('networking-visibility-switch');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(networkingVisibilityProvider);
    final visible = state.visible;
    if (visible == null) return const SizedBox.shrink();
    final notifier = ref.read(networkingVisibilityProvider.notifier);

    Future<void> change(bool on) async {
      final stuck = await notifier.set(on);
      if (!stuck && context.mounted) {
        final error = ref.read(networkingVisibilityProvider).error;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(error ?? "Couldn't change that. Try again.")));
      }
    }

    return Semantics(
      container: true,
      toggled: visible,
      label: visible
          ? 'You’re visible to others here'
          : 'You’re hidden from others here',
      onTap: () => change(!visible),
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: visible ? AppColors.paleYellow : AppColors.softGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: visible ? AppColors.border : const Color(0xFFE0E0E0),
              width: visible ? 1 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Text(visible ? '👋' : '🙈',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visible
                        ? 'You’re visible to others here'
                        : 'You’re hidden from others here',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    visible
                        ? 'People who share your interests can find you.'
                        : 'Nobody here sees you. You can still look.',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF5F5F5F)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AppToggle(key: switchKey, value: visible, onChanged: change),
          ],
        ),
      ),
    );
  }
}
