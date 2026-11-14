import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// `/profile/public/preview`: the person's profile exactly as someone who
/// hasn't met them sees it -- asked of the server as nobody, so what is
/// hidden is hidden.
class StrangerPreviewPage extends ConsumerStatefulWidget {
  const StrangerPreviewPage({super.key});

  static const bannerKey = ValueKey('stranger-preview-banner');

  @override
  ConsumerState<StrangerPreviewPage> createState() =>
      _StrangerPreviewPageState();
}

class _StrangerPreviewPageState extends ConsumerState<StrangerPreviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(myProfileProvider.notifier).ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final handle = ref.watch(myProfileProvider).profile?.handle;
    final lookup =
        handle == null ? null : ref.watch(strangerViewProvider(handle));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AS A STRANGER SEES IT',
            style: TextStyle(fontSize: 22, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
      ),
      body: lookup == null
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.ink))
          : lookup.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.ink)),
              error: (e, _) => ErrorView(
                message: extractErrorMessage(e,
                    defaultMessage: "Couldn't load the preview."),
                onRetry: () => ref.invalidate(strangerViewProvider(handle!)),
              ),
              data: (found) => switch (found) {
                ProfileFound(:final profile) => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Container(
                        key: StrangerPreviewPage.bannerKey,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.paleYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "This is what someone who hasn't met you sees, on "
                          'the app and at your link.',
                          style: TextStyle(fontSize: 13.5),
                        ),
                      ),
                      ProfileHeader(profile: profile),
                      ProfileBody(profile: profile),
                    ],
                  ),
                ProfileMissing() => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "Strangers can't see your profile right now.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              },
            ),
    );
  }
}
