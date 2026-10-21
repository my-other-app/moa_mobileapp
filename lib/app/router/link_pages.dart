import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/app/router/pending_location.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/main/presentation/providers/navigation_index_provider.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_detail_page.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:finnet/shared/utils/external_links.dart';

const _ink = Color(0xFF2C333D);

/// What a link the app cannot show opens: a plain word that it isn't here,
/// the website's page for it, and the way home. Never the address or an
/// error's text.
class LinkNotFoundPage extends ConsumerWidget {
  const LinkNotFoundPage({
    super.key,
    this.location,
    this.title = 'This page isn\'t in the app',
    this.message = 'It may have moved, or it may open only on the website.',
  });

  /// The app location that was asked for; its website page is offered when
  /// it is one of the site's.
  final String? location;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final web = location == null ? null : websiteUriFor(location!);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _bar(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.travel_explore, size: 64, color: Colors.grey[500]),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[850],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 28),
                if (web != null)
                  FilledButton.icon(
                    onPressed: () => ref.read(linkLauncherProvider)(web),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open in browser'),
                    style: FilledButton.styleFrom(backgroundColor: _ink),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.read(navigationIndexProvider.notifier).state = 0;
                    context.go('/');
                  },
                  style: TextButton.styleFrom(foregroundColor: _ink),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `/certificates/{ticketId}`: a certificate from its link (the website's
/// address, which people share and which the certificate's QR names).
///
/// The person's own certificate opens the app's certificate screen. Anyone
/// else's -- or anyone's while signed out -- is the website's public page,
/// opened inside the app.
class CertificateLinkPage extends ConsumerWidget {
  const CertificateLinkPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn =
        ref.watch(authStateProvider.select((auth) => auth.isAuthenticated));
    if (!signedIn) return _CertificateOnWeb(ticketId: ticketId);
    final mine = ref.watch(certificatesProvider);
    // Opened from an event's VIEW CERTIFICATE: the person's other
    // certificates are kept for offline too, as the list keeps them.
    ref.watch(certificatesKeptProvider);
    return mine.when(
      data: (certificates) {
        final certificate = _find(certificates);
        return certificate == null
            ? _CertificateOnWeb(ticketId: ticketId)
            : CertificateDetailPage(certificate: certificate);
      },
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        appBar: _bar(context, title: 'Certificate'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      // The list could not be loaded: the public page still can.
      error: (_, __) => _CertificateOnWeb(ticketId: ticketId),
    );
  }

  Certificate? _find(List<Certificate> certificates) {
    for (final certificate in certificates) {
      if (certificate.ticketId == ticketId) return certificate;
    }
    return null;
  }
}

class _CertificateOnWeb extends ConsumerWidget {
  const _CertificateOnWeb({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final page =
        websiteUriFor('/certificates/${Uri.encodeComponent(ticketId)}');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _bar(context, title: 'Certificate'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 64, color: Colors.grey[600]),
              const SizedBox(height: 20),
              Text(
                'A certificate from MyOtherApp',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Its page shows who earned it, for which event, and that it '
                'is genuine.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => ref.read(linkLauncherProvider)(page),
                icon: const Icon(Icons.open_in_new),
                label: const Text('View certificate'),
                style: FilledButton.styleFrom(backgroundColor: _ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sign-in screen, as the router shows it: the page itself, with a
/// "Not now" that lets the person carry on without an account.
///
/// A `?from=` address (a private page, or a screen whose action asked for
/// an account) is held so that signing in comes back to it. "Not now", or
/// Back, forgets it: the person chose not to go there.
class SignInPageFrame extends ConsumerStatefulWidget {
  const SignInPageFrame(
      {super.key, required this.location, required this.child});

  /// The sign-in screen's own address, with its `from`.
  final Uri location;
  final Widget child;

  @override
  ConsumerState<SignInPageFrame> createState() => _SignInPageFrameState();
}

class _SignInPageFrameState extends ConsumerState<SignInPageFrame> {
  @override
  void initState() {
    super.initState();
    final target = returnTarget(widget.location);
    if (target != null) ref.read(pendingLocationProvider).holdReturn(target);
  }

  void _notNow() {
    ref.read(pendingLocationProvider).clear();
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      ref.read(navigationIndexProvider.notifier).state = 0;
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // With nothing underneath (the app opened here, or a tab sent the
    // person here), Back is "Not now" rather than closing the app.
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? true;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (ref.read(authStateProvider).isAuthenticated) return;
        if (didPop) {
          ref.read(pendingLocationProvider).clear();
        } else {
          _notNow();
        }
      },
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  type: MaterialType.transparency,
                  child: TextButton(
                    key: const ValueKey('sign-in-not-now'),
                    onPressed: _notNow,
                    style: TextButton.styleFrom(
                      foregroundColor: _ink,
                      textStyle: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A page's app bar: Back when there is a page under it, else a way Home
/// (a link that opened the app straight onto this page).
PreferredSizeWidget _bar(BuildContext context, {String? title}) {
  final canPop = GoRouter.maybeOf(context)?.canPop() ?? false;
  return AppBar(
    title: title == null ? null : Text(title),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    automaticallyImplyLeading: canPop,
    leading: canPop
        ? null
        : IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/'),
          ),
  );
}
