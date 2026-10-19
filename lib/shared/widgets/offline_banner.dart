import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:finnet/core/network/network_status.dart';

/// The app's one offline cue: a slim strip under the status bar, on every
/// screen, while the server cannot be reached -- "You're offline, showing
/// what's saved". Screens that have a saved copy keep showing it
/// underneath; there are no per-screen banners.
///
/// It goes by itself when the app is back online, which is also when the
/// screens on show read themselves again ([NetworkStatus.backOnline]). A
/// tap checks at once rather than waiting for the next probe.
///
/// The child keeps its place in the tree whether or not the strip shows,
/// so the navigator and every screen keep their state when it comes and
/// goes; only the top padding the child is given changes.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child, this.status});

  final Widget child;

  /// Defaults to [NetworkStatus.instance].
  final NetworkStatus? status;

  static const message = "You're offline, showing what's saved";

  /// The strip, for finding it in tests.
  static const stripKey = ValueKey('offline-banner');

  @override
  Widget build(BuildContext context) {
    final status = this.status ?? NetworkStatus.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: status.offline,
      child: child,
      builder: (context, offline, child) {
        final media = MediaQuery.of(context);
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: offline
                  ? _Strip(top: media.padding.top, onRetry: status.checkNow)
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: MediaQuery(
                data: offline
                    ? media.copyWith(
                        padding: media.padding.copyWith(top: 0),
                        viewPadding: media.viewPadding.copyWith(top: 0),
                      )
                    : media,
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.top, required this.onRetry});

  final double top;
  final AsyncValueGetter<bool> onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: OfflineBanner.stripKey,
      color: const Color(0xFF2C333D),
      child: InkWell(
        onTap: onRetry,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 4, 16, 5),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 14, color: Colors.white70),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  OfflineBanner.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
