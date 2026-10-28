import 'package:finnet/core/services/app_badge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_badge_fakes.dart';

void main() {
  group('AppBadge, on an iPhone', () {
    test('puts the count on the icon through the app\'s own channel', () async {
      final channel = FakeBadgeChannel.install();

      await channel.badge().show(3);

      expect(channel.calls.single.method, 'set');
      expect(channel.calls.single.arguments, 3);
      expect(channel.shown, 3);
    });

    test('nothing unread, or clearing, is 0 -- never a negative number',
        () async {
      final channel = FakeBadgeChannel.install();
      final badge = channel.badge();

      await badge.show(0);
      await badge.show(-2);
      await badge.clear();

      expect(channel.counts, [0, 0, 0]);
    });

    test('sends the same count again: a push may have changed the icon since',
        () async {
      final channel = FakeBadgeChannel.install();
      final badge = channel.badge();

      await badge.show(2);
      await badge.show(2);

      expect(channel.counts, [2, 2]);
    });

    test('a badge iOS will not set is not an error', () async {
      final channel = FakeBadgeChannel.install()
        ..fail = PlatformException(code: 'badge_failed');

      await expectLater(channel.badge().show(4), completes);
      expect(channel.calls, hasLength(1));
    });

    test('an app without the channel (an older build) carries on', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // No handler installed: the call fails with MissingPluginException.
      await expectLater(AppBadge(supported: true).show(1), completes);
    });
  });

  group('AppBadge, elsewhere', () {
    test('Android: nothing is sent; the launcher\'s dots are its own',
        () async {
      final channel = FakeBadgeChannel.install();

      await AppBadge(supported: false).show(5);
      await AppBadge(supported: false).clear();

      expect(channel.calls, isEmpty);
    });

    test('by default it follows the platform', () async {
      final channel = FakeBadgeChannel.install();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await AppBadge().show(1);
      expect(channel.calls, isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await AppBadge().show(1);
      expect(channel.counts, [1]);
    });
  });
}
