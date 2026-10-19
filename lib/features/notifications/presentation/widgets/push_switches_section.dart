import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/notifications/presentation/providers/push_settings_provider.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

/// The notification switches at the top of Settings: new events in your
/// topics ("Event Notification"), the followed clubs' posts and events
/// ("Club Updates"), announcements. Each is kept by the server, which stops
/// the pushes and takes the device out of their FCM topics. Nothing is
/// shown while they load, or when the server keeps none.
///
/// Rows of the Settings design, each followed by its divider, so the list
/// goes on beneath them.
class PushSwitchesSection extends ConsumerWidget {
  const PushSwitchesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pushSwitchesProvider);
    final switches = state.switches;
    if (switches == null) return const SizedBox.shrink();
    final notifier = ref.read(pushSwitchesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...dividedRows([
          SettingsRow(
            key: const ValueKey('push-switch-topics'),
            asset: AssetResources.eventnotification,
            label: 'Event Notification',
            value: switches.topics,
            onChanged: (on) => notifier.set(topics: on),
          ),
          SettingsRow(
            key: const ValueKey('push-switch-clubs'),
            asset: AssetResources.clubsupdate,
            label: 'Club Updates',
            value: switches.clubs,
            onChanged: (on) => notifier.set(clubs: on),
          ),
          SettingsRow(
            key: const ValueKey('push-switch-platform'),
            emoji: '📣',
            label: 'Announcements',
            value: switches.platform,
            onChanged: (on) => notifier.set(platform: on),
          ),
        ]),
        if (state.error != null)
          SettingsCaption(state.error!, color: Colors.red),
        const SettingsDivider(),
      ],
    );
  }
}
