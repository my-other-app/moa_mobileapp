import 'package:finnet/core/services/app_badge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The icon badge's platform channel, faked: AppDelegate.swift's
/// `AppIconBadge` as the app sees it. Records each number the app put on
/// the icon; [fail] makes the next calls throw, as iOS refusing would.
class FakeBadgeChannel {
  FakeBadgeChannel._();

  static const channel = MethodChannel(AppBadge.channelName);

  /// Every number set, in order.
  final List<int> counts = [];

  /// Every call, for the method name and the argument as sent.
  final List<MethodCall> calls = [];

  /// When set, every call fails with it.
  PlatformException? fail;

  /// The number on the icon now, or null if nothing was ever set.
  int? get shown => counts.isEmpty ? null : counts.last;

  /// Install the fake for this test, and take it out after.
  static FakeBadgeChannel install() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fake = FakeBadgeChannel._();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      fake.calls.add(call);
      if (fake.fail != null) throw fake.fail!;
      if (call.method == 'set') fake.counts.add(call.arguments as int);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return fake;
  }

  /// An [AppBadge] that talks to this fake, as on an iPhone.
  AppBadge badge() => AppBadge(supported: true);
}
