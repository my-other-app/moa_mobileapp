import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/presentation/providers/privacy_choices_provider.dart';

/// "Share usage analytics" and "Send crash reports": what the app may send
/// about itself. Both start on; each is kept on this phone and applied the
/// moment it changes, and again at every start.
///
/// Two switches rather than one, because they are different things: an
/// analytics opt-out should not have to give up getting a crash fixed.
class PrivacySwitchesSection extends ConsumerWidget {
  const PrivacySwitchesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(privacyChoicesProvider);
    final notifier = ref.read(privacyChoicesProvider.notifier);

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
          child: Text('Privacy', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        tile(
          'privacy-switch-analytics',
          'Share usage analytics',
          'Which screens get used, so we know what to improve. Never your '
              'name or email.',
          choices.analytics,
          notifier.setAnalytics,
        ),
        tile(
          'privacy-switch-crash-reports',
          'Send crash reports',
          'When the app crashes, a report goes to us so we can fix it.',
          choices.crashReports,
          notifier.setCrashReports,
        ),
        const Divider(height: 0),
      ],
    );
  }
}
