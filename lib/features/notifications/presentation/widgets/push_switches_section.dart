import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/notifications/presentation/providers/push_settings_provider.dart';

/// The notification switches on the settings screen: the followed clubs'
/// posts and events, new events in your topics, announcements. Each is kept
/// by the server, which stops the pushes and takes the device out of their
/// FCM topics. Nothing is shown while they load, or when the server keeps
/// none.
class PushSwitchesSection extends ConsumerWidget {
  const PushSwitchesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pushSwitchesProvider);
    final switches = state.switches;
    if (switches == null) return const SizedBox.shrink();
    final notifier = ref.read(pushSwitchesProvider.notifier);

    Widget tile(String key, String title, String subtitle, bool value,
            ValueChanged<bool> onChanged) =>
        SwitchListTile(
          key: ValueKey(key),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: const Color(0xFF17A58F),
          title: Text(title),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          value: value,
          onChanged: onChanged,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4),
          child: Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        tile(
            'push-switch-clubs',
            'Clubs you follow',
            'Their new posts and events',
            switches.clubs,
            (on) => notifier.set(clubs: on)),
        tile(
            'push-switch-topics',
            'Your topics',
            'New events in the topics of your interests',
            switches.topics,
            (on) => notifier.set(topics: on)),
        tile('push-switch-platform', 'Announcements', 'News from MyOtherApp',
            switches.platform, (on) => notifier.set(platform: on)),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(state.error!,
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
        const Divider(height: 0),
      ],
    );
  }
}
