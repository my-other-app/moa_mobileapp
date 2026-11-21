import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_room.dart';
import 'package:finnet/features/live/presentation/pages/live_room_page.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

void main() {
  late List<PollAnswer> sent;

  setUp(() {
    sent = [];
    AppImageCaches.debugOverride(public: SlowImages(), private: SlowImages());
  });
  tearDown(AppImageCaches.debugOverride);

  Future<void> pumpPoll(WidgetTester tester, Map<String, dynamic> json,
      {DateTime Function()? now, bool closed = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PollCard(
              poll: LivePoll.fromJson(json)!,
              closed: closed,
              now: now,
              onAnswer: (a) async {
                sent.add(a);
                return true;
              },
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('multiple choice: up to the number, then sent as labels',
      (tester) async {
    await pumpPoll(tester, v2PollJson(settings: {'max_choices': 2}));
    expect(find.text('Pick up to 2.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('poll-pick-AI')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('poll-pick-Mobile')));
    await tester.pump();
    expect(find.bySemanticsLabel('AI, picked'), findsOneWidget);
    // The third is not offered once two are picked.
    final web = tester.widget<InkWell>(find.descendant(
        of: find.byKey(const ValueKey('poll-pick-Web')),
        matching: find.byType(InkWell)));
    expect(web.onTap, isNull);
    expect(find.text('Send 2 answers'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('poll-send')));
    await tester.pump();
    expect(sent.single.values, ['AI', 'Mobile']);
  });

  testWidgets('multiple choice answered: the room\'s share of each, as asked',
      (tester) async {
    await pumpPoll(
      tester,
      v2PollJson(
        settings: {'max_choices': 2, 'show': 'count'},
        results: {
          'responses': 4,
          'choices': [
            {'label': 'AI', 'count': 3, 'pct': 75},
            {'label': 'Web', 'count': 2, 'pct': 50},
            {'label': 'Mobile', 'count': 1, 'pct': 25},
          ],
        },
        myResponse: '0,1',
        myValues: ['AI', 'Web'],
      ),
    );
    expect(find.text('You voted AI, Web'), findsOneWidget);
    expect(find.text('3 votes'), findsOneWidget);
    expect(find.text('75%'), findsNothing, reason: 'counts only');
    expect(find.text('Change my answer'), findsOneWidget);
  });

  testWidgets('a donut or columns, each with its legend', (tester) async {
    final results = {
      'responses': 4,
      'choices': [
        {'label': 'AI', 'count': 3, 'pct': 75},
        {'label': 'Web', 'count': 1, 'pct': 25},
        {'label': 'Mobile', 'count': 0, 'pct': 0},
      ],
    };
    await pumpPoll(
        tester,
        v2PollJson(
            settings: {'chart': 'donut'}, results: results, myResponse: 'AI'));
    expect(find.byKey(const ValueKey('poll-donut')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Results: AI, 75% · 3 votes')),
        findsOneWidget);
    await pumpPoll(
        tester,
        v2PollJson(
            id: 'p2',
            settings: {'chart': 'column', 'show': 'percent'},
            results: results,
            myResponse: 'AI'));
    expect(find.byKey(const ValueKey('poll-columns')), findsOneWidget);
    expect(find.text('75%'), findsWidgets);
  });

  testWidgets('a rating to 10 as numbers, its average and spread',
      (tester) async {
    await pumpPoll(
        tester,
        v2PollJson(
            kind: 'rating', options: const [], settings: {'scale': 10}));
    expect(find.byKey(const ValueKey('rate-10')), findsOneWidget);
    final ten = tester.getSize(find.byKey(const ValueKey('rate-10')));
    expect(ten.width, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('7 of 10'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rate-7')));
    await tester.pump();
    expect(sent.single.value, '7');
    await pumpPoll(
      tester,
      v2PollJson(
        id: 'p2',
        kind: 'rating',
        options: const [],
        settings: {'scale': 10},
        myResponse: '7',
        results: {
          'responses': 2,
          'rating': {
            'average': 7.5,
            'histogram': [
              for (var v = 1; v <= 10; v++)
                {'value': v, 'count': v == 7 || v == 8 ? 1 : 0, 'pct': v == 7 || v == 8 ? 50 : 0},
            ],
          },
        },
      ),
    );
    expect(find.text('You rated 7 of 10'), findsOneWidget);
    expect(find.text('Room average 7.5 of 10'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Scores: ')), findsOneWidget);
  });

  testWidgets('a ranking: arrows to order it, then the room\'s ranking',
      (tester) async {
    await pumpPoll(tester, v2PollJson(kind: 'ranking'));
    expect(find.bySemanticsLabel('1 of 3: AI'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rank-up-Mobile')));
    await tester.pump();
    expect(find.bySemanticsLabel('2 of 3: Mobile'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('poll-send')));
    await tester.tap(find.byKey(const ValueKey('poll-send')));
    await tester.pump();
    expect(sent.single.order, ['AI', 'Mobile', 'Web']);

    await pumpPoll(
      tester,
      v2PollJson(
        id: 'p2',
        kind: 'ranking',
        myResponse: '0,2,1',
        myValues: ['AI', 'Mobile', 'Web'],
        results: {
          'responses': 3,
          'ranking': [
            {'label': 'Web', 'average': 1.3, 'points': 5, 'first': 2},
            {'label': 'AI', 'average': 2.0, 'points': 3, 'first': 1},
            {'label': 'Mobile', 'average': 2.7, 'points': 1, 'first': 0},
          ],
        },
      ),
    );
    expect(find.text('Your ranking: AI, Mobile, Web'), findsOneWidget);
    await tester.ensureVisible(find.text('The room’s ranking'));
    expect(find.bySemanticsLabel('1st, Web, average place 1.3 · 2 put it first'),
        findsOneWidget);
  });

  testWidgets('open text: a name when it is not anonymous; moderated',
      (tester) async {
    await pumpPoll(
      tester,
      v2PollJson(
        kind: 'text',
        options: const [],
        settings: {'anonymous': false},
        results: {
          'responses': 2,
          'texts': [
            {'id': 't1', 'text': 'More demos', 'name': 'Ravi', 'at': '2030-12-01T10:00:00Z'},
          ],
        },
      ),
    );
    expect(find.text('The organiser reads answers before they show.'),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('poll-name')), 'Asha');
    await tester.enterText(
        find.byKey(const ValueKey('poll-text')), 'Longer breaks please');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('poll-send')));
    await tester.pump();
    expect(sent.single.toJson(),
        {'value': 'Longer breaks please', 'name': 'Asha'});
    await pumpPoll(
      tester,
      v2PollJson(
        id: 'p2',
        kind: 'text',
        options: const [],
        myResponse: 'Longer breaks please',
        results: {
          'responses': 3,
          'texts': [
            {'id': 't1', 'text': 'More demos', 'name': null, 'at': '2030-12-01T10:00:00Z'},
          ],
        },
      ),
    );
    expect(find.text('Sent — the organiser will put it up'), findsOneWidget);
    expect(find.bySemanticsLabel('More demos'), findsOneWidget);
    expect(find.byKey(const ValueKey('poll-name')), findsNothing,
        reason: 'anonymous by default');
  });

  testWidgets('results kept from guests: said, and not shown', (tester) async {
    await pumpPoll(
      tester,
      v2PollJson(
        settings: {'hide_results': true},
        resultsHidden: true,
        results: {'responses': 9},
        myResponse: 'AI',
      ),
    );
    expect(find.text('The results are on the big screen.'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await pumpPoll(
      tester,
      v2PollJson(
        id: 'p2',
        settings: {'results': 'closed'},
        resultsHidden: true,
        results: {'responses': 9},
        myResponse: 'AI',
      ),
    );
    expect(find.text('The results show when the poll closes.'), findsOneWidget);
  });

  testWidgets('one answer only: the poll says so and takes no more',
      (tester) async {
    await pumpPoll(
        tester,
        v2PollJson(
          settings: {'change_vote': false},
          myResponse: 'AI',
          results: {
            'responses': 1,
            'choices': [
              {'label': 'AI', 'count': 1, 'pct': 100},
              {'label': 'Web', 'count': 0, 'pct': 0},
              {'label': 'Mobile', 'count': 0, 'pct': 0},
            ],
          },
        ));
    expect(find.text('Your answer is in. This poll takes one answer.'),
        findsOneWidget);
    await tester.tap(find.text('Web'));
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('a timer: "Closes in", then nothing more is taken',
      (tester) async {
    var now = DateTime.utc(2030, 12, 1, 10, 4, 18);
    await pumpPoll(tester, v2PollJson(closesAt: '2030-12-01T10:05:00Z'),
        now: () => now);
    expect(find.text('Closes in 0:42'), findsOneWidget);
    now = now.add(const Duration(seconds: 42));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Closing…'), findsOneWidget);
    await tester.tap(find.text('Web'));
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('pictures on the options', (tester) async {
    await pumpPoll(
        tester,
        v2PollJson(optionImages: [
          null,
          {'thumbnail': 'https://cdn.test/web.webp'},
          null
        ]));
    expect(find.byType(AppNetworkImage), findsOneWidget);
  });

  testWidgets('a kind newer than the app says to update', (tester) async {
    await pumpPoll(tester, v2PollJson(kind: 'slider'));
    expect(find.byKey(const ValueKey('poll-needs-update')), findsOneWidget);
    expect(find.text('AI'), findsNothing);
  });

  testWidgets('the room in the event\'s look: its logo and its page, and a '
      'multiple choice answered through the room', (tester) async {
    final api = FakeLiveRoomApi();
    api.rooms.add({
      ...roomJson(poll: v2PollJson(settings: {'max_choices': 2})),
      'theme': {
        'custom': true,
        'version': 'v1',
        'theme': themeJson(
          logo: mediaJson(),
          bg: {'kind': 'image', 'gradient': null, 'image': mediaJson('bg'), 'dim': 0.5},
          guest: {
            'text_scale': 1.1,
            'logo': true,
            'background': 'theme',
            'answer_layout': 'column'
          },
        ),
      },
    });
    api.respondAnswer = (id, value) => v2PollJson(
        settings: {'max_choices': 2},
        myResponse: '0,1',
        myValues: ['AI', 'Web'],
        results: {'responses': 1});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveRoomApiProvider.overrideWithValue(api),
        liveIdentityProvider.overrideWithValue(LiveIdentity(MemoryLiveStore())),
      ],
      child: const MaterialApp(home: LiveRoomPage(eventRef: '7')),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const ValueKey('live-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-backdrop')), findsOneWidget);
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.backgroundColor, const Color(0xFF0B0E0D));
    await tester.tap(find.byKey(const ValueKey('poll-pick-AI')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('poll-pick-Web')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('poll-send')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(api.pollAnswers.single.values, ['AI', 'Web']);
    expect(find.text('You voted AI, Web'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('every tap target of the new polls is big enough and named',
      (tester) async {
    await pumpPoll(tester, v2PollJson(kind: 'ranking'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await pumpPoll(
        tester,
        v2PollJson(
            id: 'p2', kind: 'rating', options: const [], settings: {'scale': 10}));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
