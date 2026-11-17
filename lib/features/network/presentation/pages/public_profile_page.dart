import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/network/data/network_files.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// Hands a profile's link to the share sheet; a provider for tests.
final profileLinkSharerProvider = Provider<Future<void> Function(String text)>(
  (ref) => (text) => Share.share(text),
);

/// `/u/<handle>` (the website's address too): someone's profile, as this
/// viewer may see it, with Save, their contact card, and report and block.
/// Open without an account; saving asks for one.
///
/// `?save=1` (the website's "Save to your network", and a personal QR's
/// page on the site) puts the Save offer first, above the profile.
class PublicProfilePage extends ConsumerStatefulWidget {
  const PublicProfilePage(
      {super.key, required this.handle, this.saveIntent = false});

  final String handle;

  /// They came here to save the person.
  final bool saveIntent;

  static const saveKey = ValueKey('profile-save');
  static const savedKey = ValueKey('profile-saved');
  static const editKey = ValueKey('profile-edit');
  static const missingKey = ValueKey('profile-missing');
  static const menuKey = ValueKey('profile-menu');

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  /// Saved here since the page was read.
  ProfileRelation? _relation;
  bool _saving = false;

  String get _handle => widget.handle.toLowerCase();

  Future<void> _save(PublicProfile profile) async {
    if (!ensureSignedIn(
        context,
        ref,
        'Sign in to save ${profile.fullName.split(' ').first} to your '
        'network.',
        returnTo: widget.saveIntent
            ? '${profileRoute(_handle)}?save=1'
            : profileRoute(_handle))) {
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final attempt = await ref.read(networkSaverProvider.notifier).save(
          handle: _handle,
          method: MetHow.link,
          eventId: ref.read(atEventIdProvider),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (attempt) {
      case Saved(:final result):
        setState(() => _relation = result.profile?.relation ??
            (profile.relation ?? const ProfileRelation())
                .saved(result.person.id, mutual: result.person.mutual));
        showToast(
            context,
            result.person.mutual
                ? "You've saved each other."
                : 'Saved to your network.');
      case SavedLater():
        setState(() => _relation =
            (profile.relation ?? const ProfileRelation()).saved(null));
        showToast(context, "Saved. It'll sync when you're back online.",
            icon: Icons.cloud_off);
      case SaveRefused(:final message):
        showToast(context, message, icon: Icons.error_outline);
    }
  }

  Future<void> _saveContact(PublicProfile profile) async {
    try {
      final card = await ref.read(profilesApiProvider).vcard(_handle);
      await ref.read(textFileSharerProvider)(
        fileName: fileNameFor(profile.fullName, 'vcf'),
        text: card,
        mimeType: 'text/vcard',
        subject: profile.fullName,
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

  Future<void> _onMenu(String choice, PublicProfile profile) async {
    final userId = profile.userId;
    switch (choice) {
      case 'share':
        await ref.read(profileLinkSharerProvider)(
            '${profile.fullName} on MyOtherApp: ${profile.publicUri}');
      case 'contact':
        await _saveContact(profile);
      case 'web':
        await ref
            .read(linkLauncherProvider)(websiteUriFor(profileRoute(_handle)));
      case 'report':
        if (userId != null) {
          await reportContent(context, ref,
              target: ReportTarget.profile(userId), what: 'profile');
        }
      case 'block':
        if (userId == null) return;
        final blocked = await confirmAndBlock(context, ref,
            userId: userId, name: profile.fullName, avatarUrl: profile.picture);
        if (blocked && mounted) {
          ref.invalidate(networkListProvider);
          if (context.canPop()) context.pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(publicProfileProvider(_handle));
    final profile = switch (lookup.valueOrNull) {
      ProfileFound(:final profile) => profile,
      _ => null,
    };
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PROFILE',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (profile != null)
            PopupMenuButton<String>(
              key: PublicProfilePage.menuKey,
              onSelected: (choice) => _onMenu(choice, profile),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'share', child: Text('Share profile link')),
                if (!profile.isMe && !profile.locked)
                  const PopupMenuItem(
                      value: 'contact', child: Text('Save contact card')),
                const PopupMenuItem(
                    value: 'web', child: Text('Open on the website')),
                if (!profile.isMe && profile.userId != null) ...[
                  const PopupMenuItem(value: 'report', child: Text('Report')),
                  const PopupMenuItem(value: 'block', child: Text('Block')),
                ],
              ],
            ),
        ],
      ),
      body: lookup.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.ink)),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't load this profile."),
          onRetry: () => ref.invalidate(publicProfileProvider(_handle)),
        ),
        data: (found) => switch (found) {
          ProfileFound(:final profile) => _page(profile),
          ProfileMissing() => const _Missing(),
        },
      ),
    );
  }

  Widget _page(PublicProfile profile) {
    final relation = _relation ?? profile.relation;
    final shown = profile.copyWith(relation: relation);
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () async {
        setState(() => _relation = null);
        final fresh = ref.refresh(publicProfileProvider(_handle).future);
        await fresh;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: _saveFirst(shown, relation)
            ? [
                _SaveOffer(name: shown.fullName.split(' ').first),
                _actions(shown, relation),
                const SizedBox(height: 20),
                ProfileHeader(profile: shown),
                ProfileBody(profile: shown),
              ]
            : [
                ProfileHeader(profile: shown),
                const SizedBox(height: 16),
                _actions(shown, relation),
                ProfileBody(profile: shown),
              ],
      ),
    );
  }

  bool _saveFirst(PublicProfile profile, ProfileRelation? relation) =>
      widget.saveIntent && !profile.isMe && relation?.savedByMe != true;

  Widget _actions(PublicProfile profile, ProfileRelation? relation) {
    final button = FilledButton.styleFrom(
      backgroundColor: AppColors.ink,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    if (profile.isMe) {
      return FilledButton.icon(
        key: PublicProfilePage.editKey,
        onPressed: () => context.push(editPublicProfileLocation),
        style: button,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit my profile'),
      );
    }
    if (relation?.savedByMe == true) {
      final id = relation?.networkId;
      return OutlinedButton.icon(
        key: PublicProfilePage.savedKey,
        onPressed:
            id == null ? null : () => context.push(networkPersonRoute(id)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink),
          minimumSize: const Size.fromHeight(50),
        ),
        icon: Icon(relation!.mutual ? Icons.handshake_outlined : Icons.check),
        label: Text(
            relation.mutual ? 'In your network · mutual' : 'In your network'),
      );
    }
    return FilledButton.icon(
      key: PublicProfilePage.saveKey,
      onPressed: _saving ? null : () => _save(profile),
      style: button,
      icon: const Icon(Icons.person_add_alt),
      label: Text(
          relation?.savedMe == true ? 'Save back' : 'Save to your network'),
    );
  }
}

/// Above the Save button, when they came to save the person.
class _SaveOffer extends StatelessWidget {
  const _SaveOffer({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('profile-save-offer'),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        'Save $name to your network, with where and when you met.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: PublicProfilePage.missingKey,
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🙈', style: TextStyle(fontSize: 44)),
            SizedBox(height: 12),
            Text("This profile isn't available",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('It may have been renamed or removed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
