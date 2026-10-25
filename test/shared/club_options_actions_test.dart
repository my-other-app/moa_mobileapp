import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/shared/widgets/clubs_option_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/events/events_fakes.dart';

/// A server that keeps no mutes: the sheet shows only the three options
/// these tests are about.
class _NoMutes implements PushSettingsRepository {
  @override
  Future<Result<bool?>> isClubMuted(int clubId) async => Either.right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The sheet for club 12, opened the way a club's row opens it; what it
/// closed with is recorded.
Future<List<Object?>> _open(WidgetTester tester,
    {bool isPinned = false, bool isHidden = false}) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final results = <Object?>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [pushSettingsRepositoryProvider.overrideWithValue(_NoMutes())],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await showModalBottomSheet<Object?>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ClubsOptionScreen(
                clubName: 'Circuit Society',
                imageUrl: '',
                clubId: 12,
                isPinned: isPinned,
                isHidden: isHidden,
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _choose(WidgetTester tester, String option) async {
  await tester.tap(find.text(option));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('offers the three options for a club neither pinned nor hidden',
      (tester) async {
    await _open(tester);

    expect(find.text('Circuit Society'), findsOneWidget);
    expect(find.text('Unfollow'), findsOneWidget);
    expect(find.text('Hide Events'), findsOneWidget);
    expect(find.text('Pin It'), findsOneWidget);
    expect(api.requests, isEmpty, reason: 'nothing is sent until a choice');
  });

  testWidgets('a pinned, hidden club offers Unpin and Show Events',
      (tester) async {
    await _open(tester, isPinned: true, isHidden: true);

    expect(find.text('Unpin'), findsOneWidget);
    expect(find.text('Show Events'), findsOneWidget);
    expect(find.text('Pin It'), findsNothing);
    expect(find.text('Hide Events'), findsNothing);
  });

  group('Unfollow', () {
    testWidgets('POST /clubs/unfollow/12, says so, and closes', (tester) async {
      api.on('POST', '/clubs/unfollow/12', {'message': 'Unfollowed'});
      final results = await _open(tester);
      await _choose(tester, 'Unfollow');

      expect(api.sent('POST', '/clubs/unfollow/12'), hasLength(1));
      expect(find.text('Unfollowed Circuit Society'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(results.single, {'action': 'unfollow', 'success': true});
    });

    testWidgets("refused: the server's reason, and the sheet stays open",
        (tester) async {
      api.on('POST', '/clubs/unfollow/12',
          {'message': 'You do not follow this club'},
          status: 400);
      final results = await _open(tester);
      await _choose(tester, 'Unfollow');

      expect(find.text('Failed to unfollow: You do not follow this club'),
          findsOneWidget);
      expect(results, isEmpty);
      expect(find.text('Unfollow'), findsOneWidget, reason: 'can try again');
    });
  });

  group('Hide Events', () {
    testWidgets("POST /clubs/hide/12 hides the club's events", (tester) async {
      api.on('POST', '/clubs/hide/12', {'message': 'ok'});
      final results = await _open(tester);
      await _choose(tester, 'Hide Events');

      expect(api.sent('POST', '/clubs/hide/12'), hasLength(1));
      expect(find.text('Events from Circuit Society hidden'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(results.single,
          {'action': 'hide', 'success': true, 'isHidden': true});
    });

    testWidgets('on a hidden club the same request shows them again',
        (tester) async {
      api.on('POST', '/clubs/hide/12', {'message': 'ok'});
      final results = await _open(tester, isHidden: true);
      await _choose(tester, 'Show Events');

      expect(api.sent('POST', '/clubs/hide/12'), hasLength(1));
      expect(find.text('Events from Circuit Society shown'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(results.single,
          {'action': 'hide', 'success': true, 'isHidden': false});
    });

    testWidgets('refused: says so, and the sheet stays open', (tester) async {
      api.on('POST', '/clubs/hide/12', {'message': 'Club not found'},
          status: 404);
      final results = await _open(tester);
      await _choose(tester, 'Hide Events');

      expect(find.textContaining('Failed to hide events: '), findsOneWidget);
      expect(find.textContaining('ApiException'), findsNothing);
      expect(results, isEmpty);
      expect(find.text('Hide Events'), findsOneWidget);
    });
  });

  group('Pin It', () {
    testWidgets('POST /clubs/pin/12 pins the club', (tester) async {
      api.on('POST', '/clubs/pin/12', {'message': 'ok'});
      final results = await _open(tester);
      await _choose(tester, 'Pin It');

      expect(api.sent('POST', '/clubs/pin/12'), hasLength(1));
      expect(find.text('Circuit Society pinned'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
          results.single, {'action': 'pin', 'success': true, 'isPinned': true});
    });

    testWidgets('Unpin on a pinned club', (tester) async {
      api.on('POST', '/clubs/pin/12', {'message': 'ok'});
      final results = await _open(tester, isPinned: true);
      await _choose(tester, 'Unpin');

      expect(api.sent('POST', '/clubs/pin/12'), hasLength(1));
      expect(find.text('Circuit Society unpinned'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(results.single,
          {'action': 'pin', 'success': true, 'isPinned': false});
    });

    testWidgets("refused: the server's reason, and the sheet stays open",
        (tester) async {
      api.on(
          'POST', '/clubs/pin/12', {'message': 'You can pin at most 5 clubs'},
          status: 400);
      final results = await _open(tester);
      await _choose(tester, 'Pin It');

      expect(find.text('Failed to pin: You can pin at most 5 clubs'),
          findsOneWidget);
      expect(results, isEmpty);
      expect(find.text('Pin It'), findsOneWidget);
    });
  });
}
