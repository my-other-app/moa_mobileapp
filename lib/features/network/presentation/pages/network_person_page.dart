import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/data/network_files.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/widgets/note_sheet.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

const _muted = Color(0xFF6B7280);

/// One person in the network (`/network/{id}`): who they are, every time
/// they were met -- where, when and how -- the owner's note and tags, and
/// their profile, contact card, remove, block and report.
class NetworkPersonPage extends ConsumerStatefulWidget {
  const NetworkPersonPage({super.key, required this.id});

  final int id;

  static const noteKey = ValueKey('network-person-note');
  static const profileKey = ValueKey('network-person-profile');
  static const menuKey = ValueKey('network-person-menu');
  static const goneKey = ValueKey('network-person-gone');

  @override
  ConsumerState<NetworkPersonPage> createState() => _NetworkPersonPageState();
}

class _NetworkPersonPageState extends ConsumerState<NetworkPersonPage> {
  Future<void> _remove(NetworkPerson person) async {
    final name = person.person.fullName;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
            "They leave your network, with your note and tags. They aren't "
            'told.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          TextButton(
              key: const ValueKey('network-remove-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await ref.read(networkApiProvider).remove(person.id);
      ref.invalidate(networkListProvider);
      final handle = person.person.handle;
      if (handle != null) ref.invalidate(publicProfileProvider(handle));
      if (!mounted) return;
      showToast(context, '$name is no longer in your network.');
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      showToast(context,
          extractErrorMessage(e, defaultMessage: "Couldn't remove them."),
          icon: Icons.error_outline);
    }
  }

  Future<void> _contact(NetworkPerson person) async {
    final handle = person.person.handle;
    if (handle == null) return;
    try {
      final card = await ref.read(profilesApiProvider).vcard(handle);
      await ref.read(textFileSharerProvider)(
        fileName: fileNameFor(person.person.fullName, 'vcf'),
        text: card,
        mimeType: 'text/vcard',
        subject: person.person.fullName,
      );
    } catch (e) {
      if (!mounted) return;
      showToast(
          context,
          extractErrorMessage(e,
              defaultMessage: "Couldn't get their contact card. Try again."),
          icon: Icons.error_outline);
    }
  }

  Future<void> _onMenu(String choice, NetworkPerson person) async {
    final userId = person.person.userId;
    switch (choice) {
      case 'contact':
        await _contact(person);
      case 'remove':
        await _remove(person);
      case 'report':
        if (userId != null) {
          await reportContent(context, ref,
              target: ReportTarget.profile(userId), what: 'profile');
        }
      case 'block':
        if (userId == null) return;
        final blocked = await confirmAndBlock(context, ref,
            userId: userId,
            name: person.person.fullName,
            avatarUrl: person.person.picture);
        if (blocked && mounted) {
          ref.invalidate(networkListProvider);
          if (context.canPop()) context.pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = ref.watch(networkPersonProvider(widget.id));
    final person = answer.valueOrNull;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (person != null)
            PopupMenuButton<String>(
              key: NetworkPersonPage.menuKey,
              onSelected: (choice) => _onMenu(choice, person),
              itemBuilder: (_) => [
                if (person.person.handle != null)
                  const PopupMenuItem(
                      value: 'contact', child: Text('Export to contacts')),
                const PopupMenuItem(
                    value: 'remove', child: Text('Remove from my network')),
                if (person.person.userId != null) ...[
                  const PopupMenuItem(value: 'report', child: Text('Report')),
                  const PopupMenuItem(value: 'block', child: Text('Block')),
                ],
              ],
            ),
        ],
      ),
      body: person != null
          ? _page(person)
          : answer.hasError
              ? statusCodeOf(answer.error) == 404
                  ? const Center(
                      key: NetworkPersonPage.goneKey,
                      child: Text("They aren't in your network any more."))
                  : ErrorView(
                      message: extractErrorMessage(answer.error,
                          defaultMessage: "Couldn't load them."),
                      onRetry: () =>
                          ref.invalidate(networkPersonProvider(widget.id)),
                    )
              : const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.ink)),
    );
  }

  Widget _page(NetworkPerson person) {
    final brief = person.person;
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => ref.refresh(networkPersonProvider(widget.id).future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Center(
            child: PersonAvatar(
                picture: brief.picture, initials: brief.initials, radius: 44),
          ),
          const SizedBox(height: 12),
          Text(brief.fullName,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (brief.line != null) ...[
            const SizedBox(height: 4),
            Text(brief.line!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 6),
          Text(
            person.mutual
                ? "🤝 You've saved each other"
                : person.savedMe
                    ? 'They saved you too'
                    : "You saved them. They haven't saved you back.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: NetworkPersonPage.noteKey,
                  onPressed: () => showNoteSheet(context, person),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      minimumSize: const Size.fromHeight(46)),
                  icon: const Icon(Icons.edit_note),
                  label: Text(person.note == null && person.tags.isEmpty
                      ? 'Add a note'
                      : 'Edit note'),
                ),
              ),
              if (brief.route != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: NetworkPersonPage.profileKey,
                    onPressed: () => context.push(brief.route!),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(46)),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Profile'),
                  ),
                ),
              ],
            ],
          ),
          if (person.note != null || person.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.softGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR NOTE · ONLY YOU SEE THIS',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                          color: _muted)),
                  if (person.note != null) ...[
                    const SizedBox(height: 6),
                    SelectableText(person.note!,
                        style: const TextStyle(fontSize: 14.5, height: 1.4)),
                  ],
                  if (person.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in person.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child:
                                Text(t, style: const TextStyle(fontSize: 12.5)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 6),
            child: Text('WHERE YOU MET',
                style: TextStyle(fontFamily: 'BebasNeue', fontSize: 22)),
          ),
          for (final e in person.encounters) _EncounterTile(encounter: e),
          if (person.encounters.isEmpty)
            const Text('No meetings recorded.',
                style: TextStyle(fontSize: 14, color: _muted)),
        ],
      ),
    );
  }
}

class _EncounterTile extends StatelessWidget {
  const _EncounterTile({required this.encounter});

  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    final event = encounter.event;
    final at = encounter.metAt;
    final when =
        at == null ? null : DateFormat('d MMM yyyy, h:mm a').format(at);
    return InkWell(
      onTap: event == null ? null : () => context.push(event.route),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(event == null ? '📍' : '🎟️',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event?.name ?? 'Not at an event',
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  Text(
                    [
                      if (when != null) when,
                      if (encounter.method != null) encounter.method!.label,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ],
              ),
            ),
            if (event != null)
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
