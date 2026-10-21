import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/events/presentation/widgets/networking/networking_visibility_switch.dart';
import 'package:finnet/features/profile/presentation/providers/privacy_choices_provider.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

/// "Usage Analytics" and "Crash Reports": what the app may send about
/// itself. Both start on; each is kept on this phone and applied the moment
/// it changes, and again at every start.
///
/// Two switches rather than one, because they are different things: an
/// analytics opt-out should not have to give up getting a crash fixed.
///
/// Then "Show me in People Like You", which the server keeps: whether
/// people at the same event can find this person.
///
/// Rows of the Settings design, with one grey line under them for what the
/// names do not say, then a divider, so the list goes on beneath them.
class PrivacySwitchesSection extends ConsumerWidget {
  const PrivacySwitchesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(privacyChoicesProvider);
    final notifier = ref.read(privacyChoicesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...dividedRows([
          SettingsRow(
            key: const ValueKey('privacy-switch-analytics'),
            emoji: '📈',
            label: 'Usage Analytics',
            value: choices.analytics,
            onChanged: notifier.setAnalytics,
          ),
          SettingsRow(
            key: const ValueKey('privacy-switch-crash-reports'),
            emoji: '🐞',
            label: 'Crash Reports',
            value: choices.crashReports,
            onChanged: notifier.setCrashReports,
          ),
        ]),
        const SettingsCaption(
          'So we can see what to improve, and fix crashes. Never your name '
          'or email.',
        ),
        const SettingsDivider(),
        const NetworkingVisibilityRow(),
      ],
    );
  }
}
