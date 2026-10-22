import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/notifications/presentation/providers/push_settings_provider.dart';
import 'package:finnet/shared/widgets/settings_row.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// The notification switches at the top of Settings: new events in your
/// topics ("Event Notification"), the followed clubs' posts and events
/// ("Club Updates"), announcements. Each is kept by the server, which stops
/// the pushes and takes the device out of their FCM topics.
///
/// Drawn from the first frame: the server's answer, the copy saved on this
/// phone, or -- the first time, with neither -- the server's defaults with
/// a quiet "Checking…" under them. Nothing is shown only on a server that
/// keeps no switches.
///
/// Rows of the Settings design, each followed by its divider, so the list
/// goes on beneath them.
class PushSwitchesSection extends ConsumerWidget {
  const PushSwitchesSection({super.key});

  static const checkingKey = ValueKey('push-switches-checking');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pushSwitchesProvider);
    final switches = state.switches;
    if (switches == null) return const SizedBox.shrink();
    final notifier = ref.read(pushSwitchesProvider.notifier);

    Future<void> change({bool? clubs, bool? topics, bool? platform}) async {
      final problem =
          await notifier.set(clubs: clubs, topics: topics, platform: platform);
      if (problem != null && context.mounted) {
        showToast(context, problem,
            icon: Icons.error_outline, duration: const Duration(seconds: 4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...dividedRows([
          SettingsRow(
            key: const ValueKey('push-switch-topics'),
            asset: AssetResources.eventnotification,
            label: 'Event Notification',
            value: switches.topics,
            onChanged: (on) => change(topics: on),
          ),
          SettingsRow(
            key: const ValueKey('push-switch-clubs'),
            asset: AssetResources.clubsupdate,
            label: 'Club Updates',
            value: switches.clubs,
            onChanged: (on) => change(clubs: on),
          ),
          SettingsRow(
            key: const ValueKey('push-switch-platform'),
            emoji: '📣',
            label: 'Announcements',
            value: switches.platform,
            onChanged: (on) => change(platform: on),
          ),
        ]),
        // Only over the defaults: a saved copy is what the server last
        // said, and is shown as it is while it is checked again.
        if (state.showingDefaults)
          SettingsCaption(
            key: checkingKey,
            state.checkFailed
                ? "Couldn't check these just now. They're the usual settings."
                : 'Checking your notification settings…',
          ),
        const SettingsDivider(),
      ],
    );
  }
}
