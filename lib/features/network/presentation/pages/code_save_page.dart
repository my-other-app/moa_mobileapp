import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/features/network/presentation/widgets/save_outcome_card.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// Whose personal QR [code] is, as this viewer may see them. Read again
/// when the person signs in or out.
final codeLookupProvider =
    FutureProvider.autoDispose.family<CodeLookup, String>((ref, code) {
  ref.watch(isAuthenticatedProvider);
  return ref.watch(profilesApiProvider).byCode(code);
});

/// `/p/<code>`: a personal QR's link -- from a phone's camera, a message,
/// an email, a push's `url` or another app. It shows whose code it is,
/// with one big Save; the person is saved only on that tap (method
/// `link`), never as the page opens: a link anyone can send is not a
/// scan, and a save opens the saver's "met" parts to the code's owner and
/// tells them who saved them (the contract's "Change after the Feature 4
/// clients audit"). Only the in-app scanner saves on scan.
///
/// Signed out, Save asks for an account and comes back here, to the
/// button.
class CodeSavePage extends ConsumerStatefulWidget {
  const CodeSavePage({super.key, required this.code});

  final String code;

  static const saveKey = ValueKey('code-save-save');
  static const savedKey = ValueKey('code-save-saved');
  static const ownKey = ValueKey('code-save-own');
  static const problemKey = ValueKey('code-save-problem');

  @override
  ConsumerState<CodeSavePage> createState() => _CodeSavePageState();
}

class _CodeSavePageState extends ConsumerState<CodeSavePage> {
  SaveAttempt? _attempt;
  bool _saving = false;

  String get _code => widget.code.trim().toLowerCase();

  /// The tap: the only way this page saves anyone.
  Future<void> _save(PublicProfile profile) async {
    final first = profile.fullName.split(' ').first;
    if (!ensureSignedIn(
        context,
        ref,
        'Sign in to save $first to your network, with where and when you '
        'met.',
        returnTo: profileCodeRoute(_code))) {
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final attempt = await ref.read(networkSaverProvider.notifier).save(
          code: _code,
          method: MetHow.link,
          eventId: ref.read(atEventIdProvider),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _attempt = attempt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(codeLookupProvider(_code));
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
      ),
      body: lookup.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.ink)),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't read this code."),
          onRetry: () => ref.invalidate(codeLookupProvider(_code)),
        ),
        data: (found) => switch (found) {
          CodeFound(:final profile) => _page(profile),
          CodeInactive() => const _Problem(
              emoji: '🔁',
              text: 'This code is no longer active. Ask them to show their '
                  'current code.'),
          CodeScanningOff() => const _Problem(
              emoji: '🚫',
              text: "They've turned off saving by QR. Ask for their profile "
                  'link instead.'),
          CodeMissing() =>
            const _Problem(emoji: '🔍', text: "We couldn't find this person."),
        },
      ),
    );
  }

  Widget _page(PublicProfile found) {
    final attempt = _attempt;
    final saved = attempt is Saved ? attempt.result : null;
    // After the tap: the profile as the server now shows it to a saver.
    final profile = saved?.profile ?? found;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ProfileHeader(profile: profile),
        const SizedBox(height: 16),
        if (attempt != null) ...[
          SaveOutcomeCard(attempt: attempt),
          const SizedBox(height: 8),
        ] else
          _action(profile),
        ProfileBody(profile: profile),
        if (attempt is Saved) ...[
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.go(networkLocation),
            child: const Text('Open my network'),
          ),
        ],
      ],
    );
  }

  Widget _action(PublicProfile profile) {
    if (profile.isMe) {
      return Column(
        key: CodeSavePage.ownKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("This is your own QR. Show it to the people you meet.",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(myQrLocation),
            child: const Text('Show my QR'),
          ),
        ],
      );
    }
    final relation = profile.relation;
    if (relation?.savedByMe == true) {
      final id = relation?.networkId;
      return OutlinedButton.icon(
        key: CodeSavePage.savedKey,
        onPressed:
            id == null ? null : () => context.push(networkPersonRoute(id)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink),
          minimumSize: const Size.fromHeight(52),
        ),
        icon: Icon(relation!.mutual ? Icons.handshake_outlined : Icons.check),
        label: Text(
            relation.mutual ? 'In your network · mutual' : 'In your network'),
      );
    }
    final first = profile.fullName.split(' ').first;
    return FilledButton.icon(
      key: CodeSavePage.saveKey,
      onPressed: _saving ? null : () => _save(profile),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.person_add_alt),
      label:
          Text(relation?.savedMe == true ? 'Save $first back' : 'Save $first'),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: CodeSavePage.problemKey,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.35)),
          ],
        ),
      ),
    );
  }
}
