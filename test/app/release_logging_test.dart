import 'package:finnet/app/release_logging.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// What [body] logs through debugPrint, as it is when [body] runs. The
  /// binding checks debugPrint is put back before the test ends.
  List<String> logged(void Function() body) {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add('$message');
    try {
      body();
    } finally {
      debugPrint = original;
    }
    return printed;
  }

  test('a release build logs nothing', () {
    final printed = logged(() {
      silenceDebugPrintInRelease(release: true);
      debugPrint('Local notification tapped: {"offer_token": "tok_123"}');
      debugPrint('Analytics: Event - api_error {endpoint: /x}');
    });

    expect(printed, isEmpty);
  });

  test('a debug build still logs', () {
    final printed = logged(() {
      silenceDebugPrintInRelease(release: false);
      debugPrint('Scanner: ready');
    });

    expect(printed, ['Scanner: ready']);
  });

  test("a tap on a push shown in the app logs its id, not its data", () {
    const response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      id: 42,
      payload: '{"type":"waitlist_offer","offer_token":"tok_9f8e7d6c5b4a"}',
    );

    final line = NotificationService.localTapLogLine(response);

    expect(line, 'Local notification tapped: 42');
    expect(line, isNot(contains('tok_')));
  });
}
