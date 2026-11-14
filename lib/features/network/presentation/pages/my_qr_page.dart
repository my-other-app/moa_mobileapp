import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:finnet/app/router/route_observer.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/pages/public_profile_page.dart'
    show profileLinkSharerProvider;
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// Turns the screen up while My QR is open, and back as it closes.
abstract class ScreenLight {
  Future<void> raise();
  Future<void> restore();
}

/// The phone's own: the app's brightness only, never the system setting.
class PhoneScreenLight implements ScreenLight {
  const PhoneScreenLight();

  @override
  Future<void> raise() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1);
    } catch (e) {
      debugPrint('PhoneScreenLight: could not raise: $e');
    }
  }

  @override
  Future<void> restore() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (e) {
      debugPrint('PhoneScreenLight: could not restore: $e');
    }
  }
}

final screenLightProvider =
    Provider<ScreenLight>((ref) => const PhoneScreenLight());

/// My QR (`/profile/qr`), full screen: the code another phone scans to
/// save the person -- any camera opens their profile, the app's scanner saves them
/// -- with their name and headline under it, so the other person knows
/// they scanned the right one. The screen is turned up while it is open.
/// Works with no signal once the code has been read once.
///
/// "Replace code" makes a new one; printed or shared copies of the old
/// one stop working at once.
class MyQrPage extends ConsumerStatefulWidget {
  const MyQrPage({super.key});

  static const qrKey = ValueKey('my-qr-code');
  static const replaceKey = ValueKey('my-qr-replace');
  static const scanningOffKey = ValueKey('my-qr-scanning-off');

  @override
  ConsumerState<MyQrPage> createState() => _MyQrPageState();
}

/// The screen is up only while this page is the one on show, in the app
/// at the front: it goes back as the app leaves the front (inactive,
/// hidden, paused) or a page opens over it, and comes up again on return.
///
/// On iOS the app's brightness is the phone's, and it stays until the
/// phone locks. The plugin puts it back only on scene events, which this
/// app -- with no `UIApplicationSceneManifest` in its Info.plist -- never
/// gets; Flutter's lifecycle comes from the application's own events, so
/// it is followed here instead.
class _MyQrPageState extends ConsumerState<MyQrPage>
    with WidgetsBindingObserver, RouteAware {
  late final ScreenLight _light = ref.read(screenLightProvider);
  bool _replacing = false;

  /// The screen is turned up now.
  bool _lit = false;

  /// Another page is open over this one.
  bool _covered = false;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _lightUp();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(myProfileProvider.notifier).ensureLoaded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
      _route = route;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _lightDown();
    super.dispose();
  }

  void _lightUp() {
    if (_lit) return;
    _lit = true;
    unawaited(_light.raise());
  }

  void _lightDown() {
    if (!_lit) return;
    _lit = false;
    unawaited(_light.restore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_covered && (_route?.isCurrent ?? true)) _lightUp();
    } else {
      _lightDown();
    }
  }

  @override
  void didPushNext() {
    _covered = true;
    _lightDown();
  }

  @override
  void didPopNext() {
    _covered = false;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _lightUp();
  }

  Future<void> _replace() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Replace your code?'),
        content: const Text(
            'You get a new QR. The old one stops working at once, wherever '
            'it was printed or shared. People already in your network stay.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          TextButton(
              key: const ValueKey('my-qr-replace-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Replace')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _replacing = true);
    try {
      await ref.read(profilesApiProvider).replaceQr();
      ref.invalidate(myQrProvider);
      if (mounted) showToast(context, 'You have a new code.');
    } catch (e) {
      if (mounted) {
        showToast(
            context,
            extractErrorMessage(e,
                defaultMessage: "Couldn't replace your code. Try again."),
            icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
  }

  Future<void> _turnScanningOn() async {
    try {
      await ref
          .read(myProfileProvider.notifier)
          .update({'scanning_enabled': true});
    } catch (e) {
      if (mounted) {
        showToast(context, extractErrorMessage(e), icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = ref.watch(myQrProvider);
    final mine = ref.watch(myProfileProvider).profile;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('MY QR',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            key: MyQrPage.replaceKey,
            onSelected: (choice) {
              if (choice == 'replace') _replace();
              if (choice == 'edit') context.push(editPublicProfileLocation);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'replace', child: Text('Replace code')),
              PopupMenuItem(value: 'edit', child: Text('Edit my profile')),
            ],
          ),
        ],
      ),
      body: qr.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.ink)),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't load your code. Connect once to get "
                  'it; after that it opens with no signal.'),
          onRetry: () => ref.invalidate(myQrProvider),
        ),
        data: (code) => _page(code, mine),
      ),
    );
  }

  Widget _page(MyQr code, MyProfile? mine) {
    // The app's own profile, while the public one loads (or offline).
    final account = ref.watch(profileProvider).profile;
    final name = mine?.profile.fullName ?? account?.fullName ?? '';
    final headline = mine?.profile.headline;
    final handle = mine?.handle;
    final scanningOff = mine != null && !mine.settings.scanningEnabled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        if (scanningOff) ...[
          Container(
            key: MyQrPage.scanningOffKey,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Saving by QR is off: people can't save you with this "
                    'code.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
                TextButton(
                    onPressed: _turnScanningOn, child: const Text('Turn on')),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: QrImageView(
              key: MyQrPage.qrKey,
              data: code.url,
              version: QrVersions.auto,
              size: 260,
              backgroundColor: Colors.white,
              semanticsLabel: 'Your QR code',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        if (headline != null) ...[
          const SizedBox(height: 4),
          Text(headline,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF374151))),
        ],
        if (handle != null) ...[
          const SizedBox(height: 4),
          Text(publicProfileUri(handle).toString().replaceFirst('https://', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ],
        const SizedBox(height: 8),
        const Text(
          'Any phone camera opens your profile. In MyOtherApp, it saves you '
          'to their network.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.35),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () =>
              context.push(savePersonScanAt(ref.read(atEventIdProvider))),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan theirs'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: handle == null
              ? null
              : () => ref.read(profileLinkSharerProvider)(
                  'Find me on MyOtherApp: ${publicProfileUri(handle)}'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share my profile link'),
        ),
        if (_replacing)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}
