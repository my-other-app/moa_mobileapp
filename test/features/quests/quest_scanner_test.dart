import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/network/data/save_queue.dart';
import 'package:finnet/features/network/presentation/pages/save_person_scanner_page.dart';
import 'package:finnet/features/network/presentation/widgets/save_outcome_card.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/providers/quest_provider.dart';
import 'package:finnet/features/quests/presentation/widgets/quest_scan_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import '../network/network_fixtures.dart';
import 'quest_fixtures.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The scanner opened from a quest's "Meet 5 people", with buttons in
/// place of the camera.
Future<void> _pumpScanner(WidgetTester tester,
    {int? eventId = 1, QuestFlag? flag}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(true),
      pendingSaveStoreProvider.overrideWithValue(MemoryPendingSaveStore()),
      if (flag != null)
        questFlagsProvider.overrideWith((ref) => QuestFlags()..note(1, flag)),
    ],
    child: MaterialApp(
      home: SavePersonScannerPage(
        eventId: eventId,
        camera: (context, onCode) => Center(
          child: TextButton(
            key: const ValueKey('scan-person'),
            onPressed: () => onCode('https://myotherapp.in/p/abcdefghjk'),
            child: const Text('scan'),
          ),
        ),
      ),
    ),
  ));
  await _settle(tester);
}

Finder get _line => find.byKey(QuestScanProgress.lineKey);

void main() {
  testWidgets('the count, and the count again after a save', (tester) async {
    final api = useFakeApi()
      ..on('GET', '/events/1/quest', questJson(networkCount: 2))
      ..on('GET', '/events/1/quest', questJson(networkCount: 3))
      ..on('POST', '/network', saveResultJson());
    await _pumpScanner(tester);
    expect(_line, findsOneWidget);
    expect(find.text('Meet 5 people: 2 of 5 met'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-person')));
    await _settle(tester);
    expect(find.byKey(SaveOutcomeCard.savedKey), findsOneWidget);
    // The server counts it a moment later: the line says it is counting.
    expect(find.byKey(QuestScanProgress.countingKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(find.text('Meet 5 people: 3 of 5 met'), findsOneWidget);
    expect(find.byKey(QuestScanProgress.countingKey), findsNothing);
    expect(api.sent('GET', '/events/1/quest'), hasLength(2));
  });

  testWidgets("the save's own count (v1.2): at once, nothing read again",
      (tester) async {
    final api = useFakeApi()
      ..on('GET', '/events/1/quest', questJson(networkCount: 2))
      ..on('POST', '/network', {
        ...saveResultJson(),
        'quest': {
          'event_id': 1,
          'tasks': [
            {
              'task_id': 't-net',
              'title': 'Meet 5 people',
              'count': 3,
              'target': 5,
              'done': false,
            },
          ],
        },
      });
    await _pumpScanner(tester);
    expect(find.text('Meet 5 people: 2 of 5 met'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scan-person')));
    await _settle(tester);
    expect(find.text('Meet 5 people: 3 of 5 met'), findsOneWidget);
    expect(find.byKey(QuestScanProgress.countingKey), findsNothing);
    await tester.pump(const Duration(seconds: 40));
    expect(api.sent('GET', '/events/1/quest'), hasLength(1));
  });

  testWidgets("a save that didn't add, by the save's own count: said",
      (tester) async {
    useFakeApi()
      ..on('GET', '/events/1/quest', questJson(networkCount: 2))
      ..on('POST', '/network', {
        ...saveResultJson(),
        'quest': {
          'event_id': 1,
          'tasks': [
            {'task_id': 't-net', 'count': 2, 'target': 5, 'done': false},
          ],
        },
      });
    await _pumpScanner(tester);
    await tester.tap(find.byKey(const ValueKey('scan-person')));
    await _settle(tester);
    expect(find.byKey(QuestScanProgress.notCountedKey), findsOneWidget);
  });

  testWidgets("the event's info says no quest: never asked", (tester) async {
    final api = useFakeApi()..on('POST', '/network', saveResultJson());
    await _pumpScanner(tester,
        flag: const QuestFlag(enabled: false, canTakePart: false, held: false));
    expect(_line, findsNothing);
    await tester.tap(find.byKey(const ValueKey('scan-person')));
    await _settle(tester);
    expect(find.byKey(SaveOutcomeCard.savedKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 40));
    expect(api.sent('GET', '/events/1/quest'), isEmpty);
  });

  testWidgets('done: said so', (tester) async {
    useFakeApi().on('GET', '/events/1/quest',
        questJson(networkCount: 5, networkDone: true));
    await _pumpScanner(tester);
    expect(find.text('Meet 5 people: done ✓'), findsOneWidget);
  });

  testWidgets('an event without a quest: no line, and the scanner as ever',
      (tester) async {
    final api = useFakeApi()..on('POST', '/network', saveResultJson());
    await _pumpScanner(tester);
    expect(_line, findsNothing);
    await tester.tap(find.byKey(const ValueKey('scan-person')));
    await _settle(tester);
    expect(find.byKey(SaveOutcomeCard.savedKey), findsOneWidget);
    // Nothing more is asked of the quest after the save.
    await tester.pump(const Duration(seconds: 40));
    expect(api.sent('GET', '/events/1/quest'), hasLength(1));
  });

  testWidgets('opened without an event: the quest is never asked',
      (tester) async {
    final api = useFakeApi();
    await _pumpScanner(tester, eventId: null);
    expect(_line, findsNothing);
    expect(api.requests.where((r) => r.path.contains('/quest')), isEmpty);
  });
}
