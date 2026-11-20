import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';

/// Where the share sheet points from.
///
/// share_plus refuses to open the sheet without a non-empty origin inside
/// the screen whenever iOS shows it as a popover: always on an iPad, and on
/// an iPhone too since iOS 26. The refusal is a `PlatformException` thrown
/// from the tap handler, so a share button without an origin silently did
/// nothing there.

/// The rect of the widget at [context] (the button tapped), in screen
/// coordinates; [fallbackShareOrigin] when it has no size yet or is gone.
Rect shareOriginOf(BuildContext? context) {
  RenderObject? box;
  try {
    box = context?.findRenderObject();
  } catch (_) {
    // A context that is no longer mounted.
    box = null;
  }
  if (box is RenderBox && box.attached && box.hasSize) {
    return anchoredShareOrigin(box.localToGlobal(Offset.zero) & box.size);
  }
  return fallbackShareOrigin();
}

/// [origin] when it is a real rect on the screen, else
/// [fallbackShareOrigin]: what every share in the app hands share_plus.
Rect anchoredShareOrigin(Rect? origin, {Size? screen}) {
  final bounds = Offset.zero & (screen ?? _screenSize());
  if (origin != null &&
      origin.isFinite &&
      !origin.isEmpty &&
      (bounds.isEmpty || bounds.contains(origin.center))) {
    final clipped = bounds.isEmpty ? origin : origin.intersect(bounds);
    if (!clipped.isEmpty) return clipped;
  }
  return fallbackShareOrigin(screen: screen);
}

/// A one-point rect a third of the way down the middle of the screen: the
/// sheet's anchor when there is no button to point at.
Rect fallbackShareOrigin({Size? screen}) {
  final size = screen ?? _screenSize();
  if (size.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
  return Rect.fromLTWH(size.width / 2, size.height / 3, 1, 1);
}

Size _screenSize() {
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final FlutterView? view = dispatcher.implicitView ??
      (dispatcher.views.isEmpty ? null : dispatcher.views.first);
  if (view == null || view.devicePixelRatio <= 0) return Size.zero;
  return view.physicalSize / view.devicePixelRatio;
}
