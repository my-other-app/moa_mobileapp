import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:finnet/core/network/network_status.dart';

/// A strip across the top of every screen while the server cannot be
/// reached: "You're offline. Showing what was saved." with a way to check
/// again. Screens that have a saved copy keep showing it underneath.
///
/// The child keeps its place in the tree whether or not the strip shows,
/// so the navigator and every screen keep their state when it comes and
/// goes; only the top padding the child is given changes.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child, this.status});

  final Widget child;

  /// Defaults to [NetworkStatus.instance].
  final NetworkStatus? status;

  static const message = "You're offline. Showing what was saved.";

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
      color: const Color(0xFF2C333D),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top + 6, 8, 6),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                OfflineBanner.message,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF9FFA1),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
