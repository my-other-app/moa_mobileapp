import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/pages/quest_page.dart';
import 'package:finnet/features/quests/presentation/providers/quest_provider.dart';
import 'package:finnet/features/quests/presentation/widgets/quest_card.dart';
import 'package:finnet/features/quests/presentation/widgets/quest_sheets.dart';
import 'package:finnet/features/quests/quest_routes.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import 'quest_fixtures.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Harness {
  final went = <String>[];
  final opened = <Uri>[];
  int ticketOpened = 0;
}

final _now = DateTime(2026, 11, 28, 11);

Future<_Harness> _pump(
  WidgetTester tester, {
  QuestCardStyle style = QuestCardStyle.light,
  bool compact = true,
  bool onlyWhenTakingPart = false,
  bool signedIn = true,
  bool withTicket = true,
  String start = '/',
  QuestFlag? flag,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = _Harness();
  GoRoute record(String path) => GoRoute(
        path: path,
        builder: (_, s) {
          h.went.add(s.uri.toString());
          return Scaffold(body: Text('at ${s.uri}'));
        },
      );
  final router = GoRouter(initialLocation: start, routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        backgroundColor: style == QuestCardStyle.dark
            ? const Color(0xFF0A0A0F)
            : Colors.white,
        body: SingleChildScrollView(
          child: QuestCard(
            eventId: 1,
            eventName: 'DevFest',
            style: style,
            compact: compact,
            onlyWhenTakingPart: onlyWhenTakingPart,
            onOpenTicket: withTicket ? () => h.ticketOpened++ : null,
            now: () => _now,
          ),
        ),
      ),
    ),
    ...questRoutes,
    record('/network/scan'),
    record('/events/:ref/live'),
    record('/events/:ref/live/quiz'),
    record('/profile/public'),
    record('/clubs/:ref'),
    record('/feedback/:event/:reg'),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(signedIn),
      // What the event's info said of its quest (§8.5), when it was read.
      if (flag != null)
        questFlagsProvider.overrideWith((ref) => QuestFlags()..note(1, flag)),
      linkLauncherProvider.overrideWithValue((uri) async {
        h.opened.add(uri);
        return true;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return h;
}

Finder get _card => find.byKey(QuestCard.cardKey);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  group('whether it shows', () {
    testWidgets('an event without a quest, or with it off: nothing',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest', {'enabled': false});
      await _pump(tester);
      expect(_card, findsNothing);
    });

    testWidgets('a server from before quests (404): nothing', (tester) async {
      useFakeApi();
      await _pump(tester);
      expect(_card, findsNothing);
    });

    testWidgets('on the ticket, only for someone taking part', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson(me: false));
      await _pump(tester,
          style: QuestCardStyle.dark,
          onlyWhenTakingPart: true,
          signedIn: false);
      expect(_card, findsNothing);
    });

    testWidgets('on the ticket: the dark card, with progress', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      await _pump(tester,
          style: QuestCardStyle.dark,
          onlyWhenTakingPart: true,
          withTicket: false);
      expect(_card, findsOneWidget);
      expect(find.text('10 more points to unlock Tier 1'), findsOneWidget);
      // No "Show ticket" on the ticket itself.
      expect(find.text('Show ticket'), findsNothing);
    });
  });

  group('paused (contract v1.3)', () {
    final held = pausedJson([
      claimJson(id: 'c-tee', variant: 'M', name: 'DevFest T-shirt'),
      claimJson(
          id: 'c-hood',
          status: 'waitlisted',
          waitlistPosition: 1,
          name: 'Cloud hoodie'),
    ]);

    testWidgets('off with a reward held: only that, and where', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', held);
      await _pump(tester);
      expect(find.byKey(QuestCard.pausedKey), findsOneWidget);
      expect(_card, findsNothing);
      expect(find.text('DevFest Quest'), findsOneWidget);
      expect(find.text('Quests are paused.'), findsOneWidget);
      expect(
          find.text('Your DevFest T-shirt (M) is still held for you — '
              'collect it at Swag desk.'),
          findsOneWidget);
      expect(
          find.text("You're still number 1 in line for the Cloud hoodie: one "
              'is kept for you as soon as one frees up.'),
          findsOneWidget);
      // Nothing to do while it is off.
      expect(find.byKey(QuestCard.codeKey), findsNothing);
      expect(find.text('Tasks'), findsNothing);
    });

    testWidgets('on the ticket too (it is theirs)', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', held);
      await _pump(tester,
          style: QuestCardStyle.dark,
          onlyWhenTakingPart: true,
          withTicket: false);
      expect(find.byKey(QuestCard.pausedKey), findsOneWidget);
    });

    testWidgets('the quest page shows it, not "no quest"', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', held);
      await _pump(tester, start: questLocation(1));
      expect(find.byKey(QuestCard.pausedKey), findsOneWidget);
      expect(find.byKey(QuestPage.emptyKey), findsNothing);
      expect(find.byKey(QuestPage.leaderboardKey), findsNothing);
    });
  });

  group("the event info's flag (§8.5)", () {
    testWidgets('no quest on, nothing held: the card is never asked for',
        (tester) async {
      final api = useFakeApi()..on('GET', '/events/1/quest', questJson());
      await _pump(tester,
          flag:
              const QuestFlag(enabled: false, canTakePart: false, held: false));
      expect(_card, findsNothing);
      expect(api.sent('GET', '/events/1/quest'), isEmpty);
    });

    testWidgets('on: asked, and shown', (tester) async {
      final api = useFakeApi()..on('GET', '/events/1/quest', questJson());
      await _pump(tester,
          flag: const QuestFlag(enabled: true, canTakePart: true, held: false));
      expect(_card, findsOneWidget);
      expect(api.sent('GET', '/events/1/quest'), hasLength(1));
    });

    testWidgets('off but held: asked, and the paused card', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/1/quest',
            pausedJson([claimJson(variant: 'M', name: 'DevFest T-shirt')]));
      await _pump(tester,
          flag:
              const QuestFlag(enabled: false, canTakePart: false, held: true));
      expect(find.byKey(QuestCard.pausedKey), findsOneWidget);
      expect(api.sent('GET', '/events/1/quest'), hasLength(1));
    });

    testWidgets('a quest switched on since the info was read: shown',
        (tester) async {
      // The info said none; a push opens the quest page, whose card is on.
      useFakeApi().on('GET', '/events/1/quest', questJson());
      await _pump(tester,
          start: questLocation(1),
          flag:
              const QuestFlag(enabled: false, canTakePart: false, held: false));
      expect(find.byType(QuestPage), findsOneWidget);
      expect(_card, findsOneWidget);
    });

    testWidgets("the ticket of someone who can't take part: not asked",
        (tester) async {
      final api = useFakeApi()..on('GET', '/events/1/quest', questJson());
      await _pump(tester,
          style: QuestCardStyle.dark,
          onlyWhenTakingPart: true,
          flag: const QuestFlag(enabled: true, canTakePart: false));
      expect(api.sent('GET', '/events/1/quest'), isEmpty);
    });
  });

  group('the card', () {
    testWidgets('tasks with ticks and points, progress, the count',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      await _pump(tester);
      expect(_card, findsOneWidget);
      expect(find.text('DevFest Quest'), findsOneWidget);
      expect(find.text('20 pts'), findsOneWidget);
      expect(find.byKey(QuestCard.progressKey), findsOneWidget);
      expect(find.text('10 more points to unlock Tier 1'), findsOneWidget);
      expect(find.text('2 of 5 met'), findsOneWidget);
      expect(find.text('Get your ticket scanned at Google Cloud booth'),
          findsOneWidget);
      // Done tasks are ticked; the compact card lists what is left first.
      expect(find.byIcon(Icons.check_circle), findsNothing,
          reason: 'five open tasks fill the compact card');
      expect(find.text('2 more tasks'), findsOneWidget);
      expect(find.text('10 pts'), findsWidgets);
    });

    testWidgets('the quest page lists everything, ticks included',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      await _pump(tester, compact: false);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.text('Check in'), findsOneWidget);
      // Locked tiers, with what they give.
      expect(find.textContaining('At 60 points · Sticker pack · sold out'),
          findsOneWidget);
    });

    testWidgets('"Meet 5 people" opens the scanner at this event',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      final h = await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.actionKey('t-net')));
      expect(h.went, ['/network/scan?event=1']);
    });

    testWidgets('the quiz opens the live room\'s quiz', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      final h = await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.actionKey('t-quiz')));
      expect(h.went, ['/events/1/live/quiz']);
    });

    testWidgets('feedback opens the survey in the app, once it is open',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest',
          questJson(feedback: 'https://myotherapp.in/feedback/1/reg-1?k=abc'));
      final h = await _pump(tester, compact: false);
      await _tap(tester, find.byKey(QuestCard.actionKey('t-feedback')));
      expect(h.went, ['/feedback/1/reg-1?k=abc']);
    });

    testWidgets('no survey yet: no button, and says so', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      await _pump(tester, compact: false);
      expect(find.byKey(QuestCard.actionKey('t-feedback')), findsNothing);
      expect(find.text('Opens when the survey does'), findsOneWidget);
    });

    testWidgets('the poster opens the guest\'s poster page', (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(tasks: [
            taskJson('t-poster',
                kind: 'poster_made',
                title: 'Make your poster',
                action: 'poster'),
            taskJson('t-follow',
                kind: 'follow_club', title: 'Follow GDG', action: 'follow'),
            taskJson('t-profile',
                kind: 'profile_complete',
                title: 'Finish your profile',
                action: 'profile'),
          ]));
      final h = await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.actionKey('t-poster')));
      expect(h.opened.single.toString(),
          'https://myotherapp.in/posters/MOA-1?s=k');
      await _tap(tester, find.byKey(QuestCard.actionKey('t-follow')));
      expect(h.went, ['/clubs/gdg-kochi']);
    });

    testWidgets('finishing the profile opens the profile editor',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(tasks: [
            taskJson('t-profile',
                kind: 'profile_complete',
                title: 'Finish your profile',
                action: 'profile'),
          ]));
      final h = await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.actionKey('t-profile')));
      expect(h.went, ['/profile/public']);
    });

    testWidgets('checking in shows the ticket, from the event page',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(tasks: [
            taskJson('t-in',
                kind: 'checked_in', title: 'Check in', action: 'ticket'),
          ]));
      final h = await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.actionKey('t-in')));
      expect(h.ticketOpened, 1);
    });

    testWidgets('a tick the organisers took back is said', (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(tasks: [
            {
              ...taskJson('t-hack', kind: 'manual', title: 'Submit your hack'),
              'me': {'count': 0, 'done': false, 'revoked': true},
            },
          ]));
      await _pump(tester);
      expect(find.text('Not counted: the organisers took this one back'),
          findsOneWidget);
      expect(find.byKey(QuestCard.actionKey('t-hack')), findsNothing);
    });

    testWidgets('a task not open yet says when, with no button',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(tasks: [
            taskJson('t-late',
                kind: 'code',
                title: 'The closing code',
                action: 'code',
                startsAt: DateTime(2026, 11, 28, 16).toUtc().toIso8601String()),
          ]));
      await _pump(tester);
      expect(find.text('Opens 4:00 PM'), findsOneWidget);
      expect(find.byKey(QuestCard.actionKey('t-late')), findsNothing);
    });

    testWidgets('a quest that has ended: said, and nothing to do',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson(open: false));
      await _pump(tester);
      expect(find.text('This quest has ended'), findsOneWidget);
      expect(find.byKey(QuestCard.actionKey('t-net')), findsNothing);
      expect(find.byKey(QuestCard.codeKey), findsNothing);
    });

    testWidgets('signed out: the overview, and a word to sign in',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson(me: false));
      await _pump(tester, signedIn: false);
      expect(_card, findsOneWidget);
      expect(find.text('Sign in with your ticket to see your progress.'),
          findsOneWidget);
      expect(find.byKey(QuestCard.actionKey('t-net')), findsNothing);
      expect(find.byKey(QuestCard.progressKey), findsNothing);
      expect(find.text('20 pts'), findsNothing);
    });

    testWidgets('"All tasks" opens the quest page', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.openKey));
      expect(find.byType(QuestPage), findsOneWidget);
    });
  });

  group('rewards', () {
    testWidgets('unlocked: the size and where to collect it', (tester) async {
      useFakeApi().on(
          'GET', '/events/1/quest', questJson(points: 30, tier1Unlocked: true));
      await _pump(tester);
      expect(find.text('Your rewards'), findsOneWidget);
      expect(find.text('DevFest T-shirt'), findsOneWidget);
      expect(find.text('Size M · Collect it at Swag desk'), findsOneWidget);
    });

    testWidgets('a size to pick: picked, and sent', (tester) async {
      final api = useFakeApi()
        ..on(
            'GET',
            '/events/1/quest',
            questJson(
                tier1Unlocked: true,
                tier1Claim: claimJson(needsSize: true, choices: [
                  {'label': 'S', 'free': 3},
                  {'label': 'L', 'free': 0},
                ])))
        ..on(
            'POST', '/events/1/quest/claims/c-1/size', claimJson(variant: 'S'));
      await _pump(tester);
      expect(find.text('Pick your size, then collect it at Swag desk'),
          findsOneWidget);
      await _tap(tester, find.byKey(QuestCard.sizeKey('r-shirt')));
      // A size with nothing left isn't offered.
      expect(find.byKey(QuestSizeSheet.sizeKey('L')), findsNothing);
      await _tap(tester, find.byKey(QuestSizeSheet.sizeKey('S')));
      expect(api.sent('POST', '/events/1/quest/claims/c-1/size').single.data,
          {'variant_label': 'S'});
      expect(find.byType(QuestSizeSheet), findsNothing);
    });

    testWidgets('waiting list, sold out and collected are each said',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(
              tier1Unlocked: true,
              tier1Claim:
                  claimJson(status: 'waitlisted', waitlistPosition: 3)));
      await _pump(tester);
      expect(
          find.text("On the waiting list (#3). We'll tell you when one is "
              'held for you.'),
          findsOneWidget);
    });

    testWidgets('collected', (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(
              tier1Unlocked: true,
              tier1Claim: claimJson(
                  status: 'collected',
                  collectedAt: DateTime(2026, 11, 28, 10, 5)
                      .toUtc()
                      .toIso8601String())));
      await _pump(tester);
      expect(find.text('Collected at 10:05 AM'), findsOneWidget);
    });

    testWidgets('collected: where (v1.3 door), never "by" a desk',
        (tester) async {
      final at = DateTime(2026, 11, 28, 10, 5).toUtc().toIso8601String();
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(
              tier1Unlocked: true,
              tier1Claim: claimJson(
                  status: 'collected', collectedAt: at, door: 'Swag desk')));
      await _pump(tester);
      expect(find.text('Collected at Swag desk at 10:05 AM'), findsOneWidget);
      expect(find.textContaining('by Swag desk'), findsNothing);
    });

    testWidgets('collected: by a person only when the server names one',
        (tester) async {
      final at = DateTime(2026, 11, 28, 10, 5).toUtc().toIso8601String();
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(
              tier1Unlocked: true,
              tier1Claim: claimJson(
                  status: 'collected',
                  collectedAt: at,
                  door: 'Swag desk',
                  collectedBy: 'Anil Kumar')));
      await _pump(tester);
      expect(find.text('Collected at Swag desk at 10:05 AM by Anil Kumar'),
          findsOneWidget);
    });

    testWidgets('done: when; ticked by the organisers: said so',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(tasks: [
            taskJson('t-in',
                kind: 'checked_in',
                title: 'Check in',
                done: true,
                source: 'auto'),
            taskJson('t-hack',
                kind: 'manual',
                title: 'Hackathon project submitted',
                done: true,
                source: 'grant'),
            taskJson('t-hand',
                kind: 'manual',
                title: 'Helped at the desk',
                done: true,
                source: 'grant',
                doneAt: null),
          ]));
      await _pump(tester);
      // 04:00 UTC is 9:30 AM in India.
      expect(find.text('Done at 9:30 AM'), findsOneWidget);
      expect(find.text('Marked done by the organisers at 9:30 AM'),
          findsOneWidget);
      expect(find.text('Marked done by the organisers'), findsOneWidget);
    });
  });

  group('a code', () {
    testWidgets('typed, sent and ticked', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/1/quest', questJson())
        ..on('POST', '/events/1/quest/code', {
          'result': 'DONE',
          'task': taskJson('t-code2',
              kind: 'code', title: 'The closing code', done: true),
          'card': questJson(points: 30),
        });
      await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.codeKey));
      await tester.enterText(find.byKey(QuestCodeSheet.fieldKey), 'Cloud 24');
      await _tap(tester, find.byKey(QuestCodeSheet.sendKey));
      expect(api.sent('POST', '/events/1/quest/code').single.data,
          {'code': 'Cloud 24'});
      expect(find.byType(QuestCodeSheet), findsNothing);
      expect(find.text('✓ The closing code'), findsOneWidget);
      expect(find.text('30 pts'), findsOneWidget);
    });

    testWidgets('wrong: said in the sheet, with the tries left',
        (tester) async {
      useFakeApi()
        ..on('GET', '/events/1/quest', questJson())
        ..on(
            'POST',
            '/events/1/quest/code',
            {
              'message': 'Wrong',
              'error_code': 'QUEST_CODE_WRONG',
              'errors': {'left': 2},
            },
            status: 404);
      await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.codeKey));
      await tester.enterText(find.byKey(QuestCodeSheet.fieldKey), 'nope');
      await _tap(tester, find.byKey(QuestCodeSheet.sendKey));
      expect(find.byKey(QuestCodeSheet.errorKey), findsOneWidget);
      expect(
          find.text(
              "That's not one of this quest's codes. 2 tries left this hour."),
          findsOneWidget);
    });

    testWidgets('too short to be one: not sent', (tester) async {
      final api = useFakeApi()..on('GET', '/events/1/quest', questJson());
      await _pump(tester);
      await _tap(tester, find.byKey(QuestCard.codeKey));
      await tester.enterText(find.byKey(QuestCodeSheet.fieldKey), ' a b ');
      await _tap(tester, find.byKey(QuestCodeSheet.sendKey));
      expect(api.sent('POST', '/events/1/quest/code'), isEmpty);
      expect(find.byKey(QuestCodeSheet.errorKey), findsOneWidget);
    });
  });

  group('the quest page', () {
    testWidgets('the leaderboard, with the viewer below it', (tester) async {
      useFakeApi()
        ..on('GET', '/events/1/quest', questJson(leaderboard: true))
        ..on('GET', '/events/1/quest/leaderboard', {
          'mode': 'points',
          'rows': [
            {'rank': 1, 'name': 'Asha K.', 'score': 120, 'me': false},
            {'rank': 2, 'name': 'Ben T.', 'score': 90, 'me': false},
          ],
          'me': {'rank': 14, 'score': 20},
        });
      await _pump(tester, start: questLocation(1));
      expect(find.byType(QuestPage), findsOneWidget);
      expect(find.text('20 pts · #14'), findsOneWidget);
      expect(find.byKey(QuestPage.leaderboardKey), findsOneWidget);
      expect(find.text('Asha K.'), findsOneWidget);
      expect(find.text('#14'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('no quest running: said, with the way to the event',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest', {'enabled': false});
      await _pump(tester, start: questLocation(1));
      expect(find.byKey(QuestPage.emptyKey), findsOneWidget);
    });

    testWidgets('the ranks as the server gives them (ties apart)',
        (tester) async {
      useFakeApi()
        ..on('GET', '/events/1/quest', questJson(leaderboard: true))
        ..on('GET', '/events/1/quest/leaderboard', {
          'mode': 'points',
          'rows': [
            {'rank': 1, 'name': 'Asha K.', 'score': 120, 'me': false},
            {'rank': 2, 'name': 'Ben T.', 'score': 120, 'me': false},
            {'rank': 3, 'name': 'Chen L.', 'score': 120, 'me': true},
          ],
          'me': {'rank': 3, 'score': 120},
        });
      await _pump(tester, start: questLocation(1));
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('Chen L. (you)'), findsOneWidget);
    });

    testWidgets("opened from a push (no name passed): the event's name",
        (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/1/quest', questJson())
        ..on('GET', '/discover/events/1', {
          'event': {'id': 1, 'name': 'Cloud Community Days x DevFest 2026'},
        });
      await _pump(tester, start: questLocation(1));
      expect(find.byKey(QuestPage.eventNameKey), findsOneWidget);
      expect(find.text('Cloud Community Days x DevFest 2026'), findsOneWidget);
      expect(api.sent('GET', '/events/info/1'), isEmpty);
    });

    testWidgets('with the name passed: that, and nothing more asked',
        (tester) async {
      final api = useFakeApi()..on('GET', '/events/1/quest', questJson());
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [isAuthenticatedProvider.overrideWithValue(true)],
        child: const MaterialApp(
          home: QuestPage(eventRef: '1', eventName: 'DevFest 2026'),
        ),
      ));
      await _settle(tester);
      expect(find.text('DevFest 2026'), findsOneWidget);
      expect(api.sent('GET', '/discover/events/1'), isEmpty);
    });
  });
}
