import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// This build's version as `<version>+<build>` (`1.1.0+6`): pubspec's
/// `version:`, as the platform has it (Info.plist, the APK). Read once,
/// started by `main()` before the first request.
class AppVersion {
  AppVersion._();

  static Future<String?>? _loading;
  static String? _value;

  /// Starts reading the version (once; later calls get the same read). A
  /// version that cannot be read is null: requests then go without it.
  static Future<String?> load([Future<String?> Function()? read]) =>
      _loading ??= _read(read ?? readAppVersion);

  static Future<String?> _read(Future<String?> Function() read) async {
    try {
      return _value = await read();
    } catch (_) {
      return null;
    }
  }

  /// Forgets the version read, for a test.
  @visibleForTesting
  static void reset() {
    _loading = null;
    _value = null;
  }
}

/// Puts `X-App-Version: <version>+<build>` on every request, so the server
/// can tell this build from an older one (conditional-questions-contract.md
/// §10). Nothing depends on it yet: the apps out there before it sent
/// nothing, and the server must keep treating a request without it as one
/// of those.
///
/// A request made while `main()`'s read is still under way waits for it --
/// the platform answers from the app's own bundle, at once. If it was never
/// started (a test) or failed, the request goes as it always has: never
/// held up, never failed, for it.
class AppVersionInterceptor extends Interceptor {
  static const header = 'X-App-Version';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var version = AppVersion._value;
    final loading = AppVersion._loading;
    if (version == null && loading != null) version = await loading;
    if (version != null && version.isNotEmpty) {
      options.headers[header] = version;
    }
    handler.next(options);
  }
}

/// `<version>+<build>`, or just the version when there is no build number;
/// null when there is no version.
String? appVersionValue(String version, String buildNumber) {
  final name = version.trim();
  final build = buildNumber.trim();
  if (name.isEmpty) return null;
  return build.isEmpty ? name : '$name+$build';
}

/// This build's version, from the platform.
Future<String?> readAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return appVersionValue(info.version, info.buildNumber);
}
