import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/profile/data/photo_picker.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/providers/support_providers.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// The help screens' bar: the title in capitals, as Settings has it.
PreferredSizeWidget supportAppBar(String title, {List<Widget>? actions}) =>
    AppBar(
      title: Text(
        title,
        style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.black,
      elevation: 0,
      actions: actions,
    );

/// Write to support: the mail app, or -- with none -- the address copied,
/// so there is always a way to reach us.
Future<void> emailSupport(BuildContext context, WidgetRef ref) async {
  final opened = await ref.read(linkLauncherProvider)(supportEmailUri);
  if (opened || !context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: supportEmail));
  if (context.mounted) {
    showToast(context, 'No email app found. $supportEmail is copied.',
        icon: Icons.copy_rounded);
  }
}

/// Instead of the desk, on a server that has none yet (a 404): the support
/// email, and the website's Help Centre.
class EmailSupportView extends ConsumerWidget {
  const EmailSupportView({super.key});

  static const emailKey = ValueKey('help-email');
  static const helpCentreKey = ValueKey('help-centre');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✉️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Write to us',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Email $supportEmail and our team will get back to you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: emailKey,
                onPressed: () => emailSupport(context, ref),
                child: const Text('EMAIL US'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: helpCentreKey,
                onPressed: () async {
                  final opened =
                      await ref.read(linkLauncherProvider)(helpCentreUri);
                  if (!opened && context.mounted) {
                    showToast(context,
                        "Couldn't open the Help Centre. Try again later.",
                        icon: Icons.error_outline);
                  }
                },
                child: const Text('HELP CENTRE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Never share passwords, OTPs or card numbers", above every message box.
class NeverShareNote extends StatelessWidget {
  const NeverShareNote({super.key});

  static const text = 'Never share passwords, OTPs or card numbers. '
      'MyOtherApp will never ask for them.';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('support-never-share'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paleYellow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7A0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔒', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// A request's status, as a small chip.
class SupportStatusChip extends StatelessWidget {
  const SupportStatusChip(this.status, {super.key});

  final SupportStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, ink) = switch (status) {
      SupportStatus.waiting => (AppColors.softYellow, const Color(0xFF6B5B00)),
      SupportStatus.resolved => (const Color(0xFFE3F5E9), const Color(0xFF1B6B3A)),
      SupportStatus.closed => (AppColors.softGrey, const Color(0xFF6B7280)),
      _ => (const Color(0xFFE8EEF9), const Color(0xFF2C4A7A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: ink),
      ),
    );
  }
}

/// The screenshots on a request or reply: a thumbnail each (with its
/// state), and "Add screenshot" while there is room.
class AttachmentTray extends ConsumerWidget {
  const AttachmentTray({super.key, required this.trayId, this.compact = false});

  final String trayId;

  /// In the reply box: no hint line.
  final bool compact;

  static const addKey = ValueKey('support-add-screenshot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(supportAttachmentsProvider(trayId));
    final tray = ref.read(supportAttachmentsProvider(trayId).notifier);
    final full = drafts.length >= maxSupportAttachments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (drafts.isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: drafts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _Thumb(
                draft: drafts[i],
                onRemove: () => tray.remove(drafts[i].id),
                onRetry: () => tray.retry(drafts[i].id),
              ),
            ),
          ),
        if (drafts.isNotEmpty) const SizedBox(height: 8),
        if (!full)
          TextButton.icon(
            key: addKey,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: () => pickScreenshot(context, ref, trayId),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: Text(drafts.isEmpty ? 'Add screenshot' : 'Add another'),
          ),
        if (!compact)
          Text(
            full
                ? SupportAttachments.limitMessage
                : 'Up to $maxSupportAttachments screenshots, 5 MB each.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
      ],
    );
  }
}

/// Asks camera or photos, picks one, and adds it to [trayId]'s screenshots;
/// says why when it cannot.
Future<void> pickScreenshot(
    BuildContext context, WidgetRef ref, String trayId) async {
  final source = await showModalBottomSheet<PhotoSource>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('support-pick-library'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from photos'),
            onTap: () => Navigator.of(sheet).pop(PhotoSource.library),
          ),
          ListTile(
            key: const ValueKey('support-pick-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  String? path;
  try {
    path = await ref.read(screenshotPickerProvider).pick(source);
  } on PhotoPickFailure catch (e) {
    if (context.mounted) showToast(context, e.message, icon: Icons.error_outline);
    return;
  }
  if (path == null || !context.mounted) return;
  final refused =
      await ref.read(supportAttachmentsProvider(trayId).notifier).add(path);
  if (refused != null && context.mounted) {
    showToast(context, refused, icon: Icons.error_outline);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.draft,
    required this.onRemove,
    required this.onRetry,
  });

  final AttachmentDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = draft.status == AttachmentStatus.failed;
    return SizedBox(
      key: ValueKey('support-attachment-${draft.id}'),
      width: 76,
      height: 76,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: failed ? onRetry : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: AppColors.softGrey,
                  child: Image.file(
                    File(draft.path),
                    fit: BoxFit.cover,
                    cacheWidth: 200,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_outlined, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (draft.status == AttachmentStatus.uploading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x88FFFFFF),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          if (failed)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xAA000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.refresh, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: Semantics(
              button: true,
              label: 'Remove screenshot',
              child: InkWell(
                key: ValueKey('support-attachment-remove-${draft.id}'),
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
