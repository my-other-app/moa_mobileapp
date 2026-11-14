import 'package:flutter/foundation.dart';

/// In a release build [debugPrint] prints nothing.
///
/// Flutter doesn't strip `debugPrint` from release builds, so every line
/// the app logs -- a push's data, analytics events with their parameters,
/// addresses that failed -- went to the device log, where anything reading
/// logcat on a rooted or debug-enabled phone, or a sysdiagnose, could see
/// it. Run first in `main`, before anything logs. Debug and profile builds
/// print as before.
void silenceDebugPrintInRelease({bool release = kReleaseMode}) {
  if (release) debugPrint = _silent;
}

void _silent(String? message, {int? wrapWidth}) {}
