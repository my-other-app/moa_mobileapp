import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/features/network/presentation/widgets/save_outcome_card.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// Whose personal QR [code] is, for someone not signed in.
final codeLookupProvider = FutureProvider.autoDispose
    .family<CodeLookup, String>(
        (ref, code) => ref.watch(profilesApiProvider).byCode(code));

/// `/p/<code>`: a personal QR's link, from a phone's camera or a shared
/// message. Signed in, the person is saved at once (the event filled in
/// when both are checked in to it) and a card offers a note. Signed out,
/// their profile, and "Save to your network", which asks for an account
/// and comes back here to finish.
class CodeSavePage extends ConsumerStatefulWidget {
  const CodeSavePage({super.key, required this.code});

  final String code;

  static const signInKey = ValueKey('code-save-sign-in');
  static const problemKey = ValueKey('code-save-problem');

  @override
  ConsumerState<CodeSavePage> createState() => _CodeSavePageState();
}

class _CodeSavePageState extends ConsumerState<CodeSavePage> {
  SaveAttempt? _attempt;
  bool _saving = false;

  String get _code => widget.code.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveIfSignedIn());
  }

  Future<void> _saveIfSignedIn() async {
    if (!mounted || !ref.read(isAuthenticatedProvider)) return;
    if (_saving || _attempt != null) return;
    setState(() => _saving = true);
    final attempt = await ref.read(networkSaverProvider.notifier).save(
          code: _code,
          method: MetHow.qr,
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
    final signedIn = ref.watch(isAuthenticatedProvider);
    // Signed in from the prompt: finish the save.
    ref.listen<bool>(isAuthenticatedProvider, (_, now) {
      if (now) _saveIfSignedIn();
    });
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SAVE A PERSON',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
      ),
      body: signedIn ? _signedIn() : _signedOut(),
    );
  }

  Widget _signedIn() {
    final attempt = _attempt;
    if (attempt == null) {
      return const Center(
          child:
              CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink));
    }
    final profile = attempt is Saved ? attempt.result.profile : null;
    final refused = attempt is SaveRefused ? attempt : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SaveOutcomeCard(attempt: attempt),
        if (refused?.code == cannotSaveSelfCode) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go(myQrLocation),
            child: const Text('Show my QR'),
          ),
        ],
        if (profile != null && !profile.locked) ...[
          const SizedBox(height: 8),
          ProfileBody(profile: profile),
        ],
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => context.go(networkLocation),
          child: const Text('Open my network'),
        ),
      ],
    );
  }

  Widget _signedOut() {
    final lookup = ref.watch(codeLookupProvider(_code));
    return lookup.when(
      loading: () => const Center(
          child:
              CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink)),
      error: (e, _) => ErrorView(
        message:
            extractErrorMessage(e, defaultMessage: "Couldn't read this code."),
        onRetry: () => ref.invalidate(codeLookupProvider(_code)),
      ),
      data: (found) => switch (found) {
        CodeFound(:final profile) => _preview(profile),
        CodeInactive() => const _Problem(
            emoji: '🔁',
            text: 'This code is no longer active. Ask them to show their '
                'current code.'),
        CodeScanningOff() => const _Problem(
            emoji: '🚫', text: "They've switched saving by QR off."),
        CodeMissing() =>
          const _Problem(emoji: '🔍', text: "We couldn't find this person."),
      },
    );
  }

  Widget _preview(PublicProfile profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ProfileHeader(profile: profile),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: CodeSavePage.signInKey,
          onPressed: () => ensureSignedIn(
            context,
            ref,
            'Sign in to save ${profile.fullName.split(' ').first} to your '
            'network, with where and when you met.',
            returnTo: profileCodeRoute(_code),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Save to your network'),
        ),
        ProfileBody(profile: profile),
      ],
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
