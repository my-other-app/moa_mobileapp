// What the DevFest render of the live room showed (feature-register/
// live-custom/devfest-demo/app): words split inside grid tiles, buttons in
// another font, points on a poll, tall donut rows and faint bars, theme
// fonts the app did not ship, and the bar at the top off-centre and not
// matching a gradient page.
import 'dart:io';

import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_room.dart';
import 'package:finnet/features/live/domain/live_theme.dart';
import 'package:finnet/features/live/presentation/pages/live_room_page.dart';
import 'package:finnet/features/live/presentation/pages/quiz_page.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:finnet/features/live/presentation/widgets/quiz_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

/// The real faces, so text is measured as a phone lays it out (the test
/// font draws every letter a square).
Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(
        Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
  }
  await loader.load();
}

/// The DevFest look the screenshots used: Meridian light, Google blue,
/// letters, a bar clock, a white to pale-blue gradient drawn on phones.
Map<String, dynamic> devfestTheme({
  String display = 'dm_sans',
  String body = 'dm_sans',
  String layout = 'grid',
  int angle = 180,
  Map<String, dynamic>? bg,
}) {
  final theme = themeJson(
    preset: 'meridian_light',
    background: '#F8F9FA',
    accent: '#4285F4',
    style: 'letters',
    timer: 'bar',
    text: {
      'on_background': '#111827',
      'on_accent': '#111827',
      'on_answers': [
        '#111827',
        '#111827',
        '#111827',
        '#111827',
        '#FFFFFF',
        '#111827'
      ],
    },
    bg: bg ??
        {
          'kind': 'gradient',
          'gradient': {'from': '#FFFFFF', 'to': '#E8F0FE', 'angle': angle},
          'image': null,
          'dim': 0.45
        },
    guest: {
      'text_scale': 1.0,
      'logo': false,
      'background': 'theme',
      'answer_layout': layout
    },
  );
  theme['font'] = {'display': display, 'body': body};
  (theme['colors'] as Map)['answers'] = [
    '#4285F4',
    '#EA4335',
    '#FBBC04',
    '#34A853',
    '#A142F4',
    '#24C1E0'
  ];
  return theme;
}

Map<String, dynamic> themed(Map<String, dynamic> theme) =>
    {'custom': true, 'version': 'v1', 'theme': theme};

const devfestOptions = [
  {'key': 'a', 'label': 'Cloud Firestore'},
  {'key': 'b', 'label': 'Crashlytics'},
  {'key': 'c', 'label': 'Kubernetes Engine'},
  {'key': 'd', 'label': 'Remote Config'},
];

const regionOptions = [
  {'key': 'a', 'label': 'asia-south1 (Mumbai)'},
  {'key': 'b', 'label': 'asia-south2 (Delhi)'},
  {'key': 'c', 'label': 'asia-southeast1 (Singapore)'},
  {'key': 'd', 'label': 'us-central1 (Iowa)'},
];

const pollOptions = [
  {'key': 'a', 'label': 'Cloud Run'},
  {'key': 'b', 'label': 'Firebase Studio'},
  {'key': 'c', 'label': 'Gemini CLI'},
  {'key': 'd', 'label': 'Flutter + Gemini API'},
];

/// No word of any answer's label laid out over two lines (a hyphen may end
/// a line: "asia-" / "south1").
void expectWholeWords(WidgetTester tester, List<String> keys) {
  for (final key in keys) {
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
        of: find.byKey(ValueKey('answer-label-$key')),
        matching: find.byType(RichText)));
    final text = paragraph.text.toPlainText();
    for (final word in RegExp(r'[^\s\-]+').allMatches(text)) {
      final lines = paragraph
          .getBoxesForSelection(
              TextSelection(baseOffset: word.start, extentOffset: word.end))
          .map((b) => b.top.round())
          .toSet();
      expect(lines, hasLength(1),
          reason: '"${word[0]}" of "$text" is split over two lines');
    }
  }
}

/// Tiles side by side are as tall as each other.
void expectBalancedRows(WidgetTester tester, List<String> keys) {
  for (var i = 0; i + 1 < keys.length; i += 2) {
    final a = tester.getRect(find.byKey(ValueKey('answer-${keys[i]}')));
    final b = tester.getRect(find.byKey(ValueKey('answer-${keys[i + 1]}')));
    if (a.top == b.top) {
      expect(a.height, b.height, reason: 'a row of the grid');
    }
  }
}

bool inGrid(WidgetTester tester) {
  final a = tester.getRect(find.byKey(const ValueKey('answer-a')));
  final b = tester.getRect(find.byKey(const ValueKey('answer-b')));
  return a.top == b.top;
}

/// The effective style of [label]'s text inside [button] (not its icon's).
TextStyle textIn(WidgetTester tester, Finder button, String label) => tester
    .widget<RichText>(find.descendant(
        of: find.descendant(of: button, matching: find.text(label)),
        matching: find.byType(RichText)))
    .text
    .style!;

void main() {
  late FakeLiveRoomApi api;
  late LiveIdentity identity;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFont('DMSans', ['assets/fonts/DMSans-VariableFont_opsz,wght.ttf']);
    await _loadFont('Inter', ['assets/fonts/Inter-Latin-VariableFont_wght.ttf']);
    await _loadFont('SpaceGrotesk',
        ['assets/fonts/SpaceGrotesk-Latin-VariableFont_wght.ttf']);
    await _loadFont('Poppins', [
      'assets/fonts/Poppins-Regular.ttf',
      'assets/fonts/Poppins-Medium.ttf',
      'assets/fonts/Poppins-SemiBold.ttf',
      'assets/fonts/Poppins-Bold.ttf',
    ]);
  });

  setUp(() {
    api = FakeLiveRoomApi();
    identity = LiveIdentity(MemoryLiveStore());
    AppImageCaches.debugOverride(public: SlowImages(), private: SlowImages());
  });
  tearDown(AppImageCaches.debugOverride);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> nextRead(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
  }

  /// An iPhone 17 Pro's width, as the screenshots were drawn.
  const phone = Size(402, 874);

  Future<void> pumpQuiz(WidgetTester tester,
      {Size size = phone, double text = 1, bool joined = true}) async {
    if (joined) {
      await identity.savePlayer(
          const QuizPlayer(eventId: 7, playerKey: 'k', name: 'Ananya'));
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveRoomApiProvider.overrideWithValue(api),
        liveIdentityProvider.overrideWithValue(identity),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'DMSans'),
          home: const QuizPage(eventRef: '7'),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> pumpRoom(WidgetTester tester) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveRoomApiProvider.overrideWithValue(api),
        liveIdentityProvider.overrideWithValue(identity),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'DMSans'),
        home: const LiveRoomPage(eventRef: '7'),
      ),
    ));
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    final list = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(finder, 200, scrollable: list);
  }

  group('1. grid tiles never split a word', () {
    testWidgets('several answers at 402 points: picking, then revealed',
        (tester) async {
      api.themeAnswer = themed(devfestTheme());
      api.quizStates
        ..add(v2QuizJson(
          question: kindQuestionJson(
            kind: 'multi',
            prompt: 'Which of these are Firebase products? Pick every one.',
            options: devfestOptions,
          ),
          themeVersion: 'v1',
        ))
        ..add(v2QuizJson(
          phase: 'revealed',
          score: 1742,
          rank: 3,
          question: kindQuestionJson(
            kind: 'multi',
            options: devfestOptions,
            timeLeft: 0,
            myResponse: {
              'option_keys': ['a', 'b', 'd']
            },
            myPoints: 870,
            myCorrect: true,
            myCredit: 1,
            correctKeys: ['a', 'b', 'd'],
          ),
          themeVersion: 'v1',
        ));
      await pumpQuiz(tester);
      const keys = ['a', 'b', 'c', 'd'];
      // "Kubernetes" and "Crashlytics" (about 92 points in DM Sans bold)
      // are wider than half the card leaves a label (80): one column.
      expect(inGrid(tester), isFalse);
      expectWholeWords(tester, keys);
      expectBalancedRows(tester, keys);
      for (final k in ['a', 'b', 'd']) {
        await tester.tap(find.byKey(ValueKey('answer-$k')));
        await tester.pump();
      }
      expect(find.text('Lock in 3 answers'), findsOneWidget);
      expectWholeWords(tester, keys);
      expectBalancedRows(tester, keys);
      await nextRead(tester);
      expect(find.text('Right — +870'), findsOneWidget);
      expectWholeWords(tester, keys);
      expectBalancedRows(tester, keys);
      await leave(tester);
    });

    testWidgets('a poll question with its pick, and hyphenated regions',
        (tester) async {
      api.themeAnswer = themed(devfestTheme());
      api.quizStates
        ..add(v2QuizJson(
          phase: 'revealed',
          question: kindQuestionJson(
            kind: 'poll',
            prompt: 'Which Google tool will you try first after today?',
            options: pollOptions,
            timeLeft: 0,
            myAnswer: 'c',
            myResponse: {'option_key': 'c'},
          ),
          themeVersion: 'v1',
        ))
        ..add(v2QuizJson(
          question: kindQuestionJson(
            id: 'q2',
            prompt: 'Which Google Cloud region is closest to Technopark?',
            options: regionOptions,
          ),
          themeVersion: 'v1',
        ));
      await pumpQuiz(tester);
      expect(find.bySemanticsLabel(RegExp(r'^C, Gemini CLI, your answer')),
          findsOneWidget);
      expect(inGrid(tester), isTrue, reason: 'every word fits half the card');
      expectWholeWords(tester, ['a', 'b', 'c', 'd']);
      expectBalancedRows(tester, ['a', 'b', 'c', 'd']);
      await nextRead(tester);
      expect(find.text('asia-southeast1 (Singapore)'), findsOneWidget);
      expectWholeWords(tester, ['a', 'b', 'c', 'd']);
      expectBalancedRows(tester, ['a', 'b', 'c', 'd']);
      await leave(tester);
    });

    testWidgets('short labels stay two to a row; large text or a narrow '
        'phone goes to one column', (tester) async {
      Future<bool> grid(List<Map<String, String>> options,
          {Size size = phone, double text = 1}) async {
        api = FakeLiveRoomApi()
          ..themeAnswer = themed(devfestTheme())
          ..quizStates.add(v2QuizJson(
              question: kindQuestionJson(kind: 'multi', options: options),
              themeVersion: 'v1'));
        identity = LiveIdentity(MemoryLiveStore());
        await pumpQuiz(tester, size: size, text: text);
        final keys = [for (final o in options) o['key']!];
        expectWholeWords(tester, keys);
        final g = inGrid(tester);
        await leave(tester);
        return g;
      }

      const short = [
        {'key': 'a', 'label': 'Cloud Run'},
        {'key': 'b', 'label': 'Android'},
        {'key': 'c', 'label': 'Flutter'},
        {'key': 'd', 'label': 'Firebase'},
      ];
      expect(await grid(short), isTrue, reason: 'room for every word');
      expect(await grid(devfestOptions, text: 1.3), isFalse,
          reason: '"Kubernetes" no longer fits half the card');
      expect(await grid(devfestOptions, size: const Size(320, 760)), isFalse,
          reason: 'a narrow phone');
      expect(await grid(short, text: 1.5), isFalse,
          reason: 'large text always reads one under the other');
    });

    testWidgets('the check itself catches a split word', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 60,
            child: Text('Kubernetes Engine',
                key: ValueKey('answer-label-x'),
                style: TextStyle(fontFamily: 'DMSans', fontSize: 16)),
          ),
        ),
      ));
      expect(() => expectWholeWords(tester, ['x']),
          throwsA(isA<TestFailure>()));
    });

    testWidgets('the rule: the longest word against the tile\'s room',
        (tester) async {
      late bool fits;
      Future<void> measure(List<String> labels, double width,
          {double text = 1}) async {
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(text)),
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'DMSans'),
            home: Builder(builder: (context) {
              fits = quizGridFits(context,
                  labels: labels, width: width, marked: true);
              return const SizedBox();
            }),
          ),
        ));
      }

      // 338 points: the quiz card's inside on a 402-point phone.
      await measure(['Cloud Firestore', 'Remote Config'], 338);
      expect(fits, isTrue);
      await measure(['Cloud Firestore', 'Remote Config'], 338, text: 1.3);
      expect(fits, isFalse);
      await measure(['Supercalifragilistic'], 338);
      expect(fits, isFalse, reason: 'one word wider than the tile');
      await measure(['Yes', 'No'], 300);
      expect(fits, isTrue);
    });
  });

  group('2. every button in the room\'s font', () {
    testWidgets('the quiz: join, lock in, lock in my answer — the theme\'s '
        'body font, one size and weight', (tester) async {
      api.themeAnswer = themed(devfestTheme(body: 'inter', layout: 'column'));
      api.quizStates
        ..add(v2QuizJson(
            question: kindQuestionJson(kind: 'multi'), themeVersion: 'v1'))
        ..add(v2QuizJson(
            question: kindQuestionJson(id: 'q2', kind: 'type', options: []),
            themeVersion: 'v1'));
      await pumpQuiz(tester);
      await tester.tap(find.byKey(const ValueKey('answer-a')));
      await tester.pump();
      final lock = textIn(
          tester, find.byKey(const ValueKey('quiz-lock-in')), 'Lock in 1 answer');
      expect(lock.fontFamily, 'Inter');
      expect(lock.fontSize, 16);
      expect(lock.fontWeight, FontWeight.w700);
      await nextRead(tester);
      expect(find.text('Lock in my answer'), findsOneWidget);
      final typed = textIn(tester, find.byKey(const ValueKey('quiz-lock-in')),
          'Lock in my answer');
      expect(typed.fontFamily, 'Inter');
      expect(typed.fontSize, 16);
      await leave(tester);
    });

    testWidgets('the room: join the quiz, ask and the votes', (tester) async {
      api.rooms.add({
        ...roomJson(
          quizLive: true,
          quizTitle: 'Round 1',
          questions: [questionJson('a', text: 'Slides?', votes: 23)],
        ),
        'theme': themed(devfestTheme(body: 'inter')),
      });
      await pumpRoom(tester);
      final join = textIn(
          tester, find.byKey(const ValueKey('quiz-join-room')), 'Join the quiz');
      expect(join.fontFamily, 'Inter');
      expect(join.fontSize, 16);
      expect(join.fontWeight, FontWeight.w700);
      await scrollTo(tester, find.byKey(const ValueKey('vote-a')));
      expect(
          textIn(tester, find.byKey(const ValueKey('vote-a')), '23').fontFamily,
          'Inter');
      final ask = textIn(
          tester,
          find.ancestor(of: find.text('Ask'), matching: find.byType(FilledButton)),
          'Ask');
      expect(ask.fontFamily, 'Inter');
      await leave(tester);
    });

    testWidgets('no theme: the app\'s DM Sans, not Bebas Neue capitals',
        (tester) async {
      api.rooms.add(roomJson(quizLive: true, quizTitle: 'Warm-up'));
      await pumpRoom(tester);
      final join = textIn(
          tester, find.byKey(const ValueKey('quiz-join-room')), 'Join the quiz');
      expect(join.fontFamily, 'DMSans');
      expect(join.fontSize, 16);
      await leave(tester);
    });
  });

  group('3. a poll question is worth no points', () {
    testWidgets('no points badge on a poll, whatever the round sends',
        (tester) async {
      api.quizStates.add(v2QuizJson(
          question: kindQuestionJson(
              kind: 'poll',
              options: pollOptions,
              effectivePoints: 2000,
              double: true)));
      await pumpQuiz(tester);
      expect(find.text('Which of these are prime?'), findsOneWidget);
      expect(find.text('2000 points'), findsNothing);
      expect(find.text('Double points'), findsNothing);
      await leave(tester);
    });
  });

  group('4. poll results', () {
    final results = {
      'responses': 187,
      'choices': [
        {'label': 'This is my first', 'count': 94, 'pct': 50},
        {'label': '2–3', 'count': 61, 'pct': 33},
        {'label': '4 or more', 'count': 32, 'pct': 17},
      ],
    };
    final look = LiveLook.from(LiveThemeState.fromJson(themed(devfestTheme())));

    Future<void> pumpPoll(WidgetTester tester, Map<String, dynamic> json) async {
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'DMSans'),
        home: LiveThemed(
          look: look,
          child: Scaffold(
            body: LiveBackdrop(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PollCard(
                    poll: LivePoll.fromJson(json)!,
                    onAnswer: (_) async => true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a donut\'s answers are plain rows, the label in the middle',
        (tester) async {
      await pumpPoll(
          tester,
          v2PollJson(
            options: const ['This is my first', '2–3', '4 or more'],
            settings: {'chart': 'donut'},
            results: results,
            myResponse: 'This is my first',
          ));
      expect(find.byKey(const ValueKey('poll-donut')), findsOneWidget);
      for (final label in ['This is my first', '2–3', '4 or more']) {
        final row = tester.getRect(find.byKey(ValueKey('poll-choice-$label')));
        expect(row.height, lessThan(56), reason: 'not a bar row\'s height');
        expect(row.height, greaterThanOrEqualTo(liveTapTarget));
        final text = tester.getRect(find.descendant(
            of: find.byKey(ValueKey('poll-choice-$label')),
            matching: find.text(label)));
        expect((text.center.dy - row.center.dy).abs(), lessThan(1.5),
            reason: 'no empty space under the label');
      }
    });

    testWidgets('bars: every fill plain on the white, the pick a step '
        'stronger, the text readable on both', (tester) async {
      await pumpPoll(
          tester,
          v2PollJson(
            options: const ['This is my first', '2–3', '4 or more'],
            results: results,
            myResponse: 'This is my first',
          ));
      final fills = [
        for (final e in find.byKey(const ValueKey('poll-bar')).evaluate())
          (e.widget as Container).color!,
      ];
      expect(fills, [look.barFillMine, look.barFill, look.barFill]);
      // The old fill (the live card's 8% tint) was 1.05:1 on the white.
      expect(liveContrast(look.barFill, Colors.white), greaterThan(1.3));
      expect(liveContrast(look.barFillMine, Colors.white),
          greaterThan(liveContrast(look.barFill, Colors.white) + 0.3));
      for (final f in fills) {
        expect(liveContrast(LiveColors.ink, f),
            greaterThanOrEqualTo(liveTextContrast));
      }
    });

    test('a dark accent still leaves the text readable on its bars', () {
      final dark = LiveLook.from(LiveThemeState.fromJson(themed({
        ...devfestTheme(),
        'colors': {
          'background': '#F8F9FA',
          'accent': '#1A237E',
          'answers': ['#DC2626', '#2563EB'],
        },
      })));
      for (final f in [dark.barFill, dark.barFillMine]) {
        expect(liveContrast(LiveColors.ink, f),
            greaterThanOrEqualTo(liveTextContrast));
        expect(liveContrast(f, Colors.white), greaterThan(1.2));
      }
      for (final f in [LiveLook.standard.barFill, LiveLook.standard.barFillMine]) {
        expect(liveContrast(LiveColors.ink, f),
            greaterThanOrEqualTo(liveTextContrast));
      }
    });
  });

  group('5. theme fonts the website uses', () {
    test('each allowed font has its own family', () {
      expect(liveFontFamily('dm_sans'), 'DMSans');
      expect(liveFontFamily('bebas_neue'), 'BebasNeue');
      expect(liveFontFamily('poppins'), 'Poppins');
      expect(liveFontFamily('space_grotesk'), 'SpaceGrotesk');
      expect(liveFontFamily('inter'), 'Inter');
      expect(liveFontFamily('noto_sans'), 'NotoSans');
      expect(liveFontFamily('comic_sans'), 'DMSans');
    });

    testWidgets('the question in the display font, the answers in the body '
        'font', (tester) async {
      api.themeAnswer = themed(
          devfestTheme(display: 'space_grotesk', body: 'poppins', layout: 'column'));
      api.quizStates.add(v2QuizJson(
          question: kindQuestionJson(options: devfestOptions),
          themeVersion: 'v1'));
      await pumpQuiz(tester);
      final prompt = tester.widget<Text>(find.text('Which of these are prime?'));
      expect(prompt.style!.fontFamily, 'SpaceGrotesk');
      final label = tester.widget<RichText>(find.descendant(
          of: find.byKey(const ValueKey('answer-label-a')),
          matching: find.byType(RichText)));
      expect(label.text.style!.fontFamily, 'Poppins');
      await leave(tester);
    });

    testWidgets('a DM Sans question under an Inter body stays DM Sans',
        (tester) async {
      api.themeAnswer = themed(devfestTheme(body: 'inter'));
      api.quizStates.add(v2QuizJson(
          question: kindQuestionJson(), themeVersion: 'v1'));
      await pumpQuiz(tester);
      final prompt = tester.widget<Text>(find.text('Which of these are prime?'));
      expect(prompt.style!.fontFamily, 'DMSans');
      await leave(tester);
    });
  });

  group('6. the bar at the top', () {
    Future<void> openQuiz(WidgetTester tester, Map<String, dynamic> theme) async {
      api.themeAnswer = themed(theme);
      api.quizStates.add(v2QuizJson(
        phase: 'lobby',
        index: -1,
        themeVersion: 'v1',
      ));
      await pumpQuiz(tester);
      // The quiz's title is the bar's second line.
      expect(find.byKey(const ValueKey('live-bar-title')), findsOneWidget);
    }

    testWidgets('iOS: both lines centred', (tester) async {
      api.quizStates.add({
        ...v2QuizJson(phase: 'lobby', index: -1),
        'title': 'Round 1 · Cloud & Firebase',
      });
      await pumpQuiz(tester);
      final title = tester.getCenter(find.text('Quiz'));
      final sub = tester.getCenter(find.text('Round 1 · Cloud & Firebase'));
      expect((title.dx - sub.dx).abs(), lessThan(1));
      expect((title.dx - phone.width / 2).abs(), lessThan(2));
      await leave(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android: both lines at the start', (tester) async {
      api.quizStates.add({
        ...v2QuizJson(phase: 'lobby', index: -1),
        'title': 'Round 1 · Cloud & Firebase',
      });
      await pumpQuiz(tester);
      final title = tester.getRect(find.text('Quiz'));
      final sub = tester.getRect(find.text('Round 1 · Cloud & Firebase'));
      expect(title.left, sub.left);
      await leave(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a gradient page runs on under a see-through bar',
        (tester) async {
      await openQuiz(tester, devfestTheme());
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, Colors.transparent);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBodyBehindAppBar,
          isTrue);
      expect(tester.getRect(find.byKey(const ValueKey('live-backdrop'))).top, 0,
          reason: 'the gradient starts at the top of the screen');
      // The page's content still starts under the bar.
      expect(tester.getRect(find.byType(ListView)).top,
          greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
      await leave(tester);
    });

    testWidgets('a plain colour page: the bar is that colour', (tester) async {
      await openQuiz(
          tester,
          devfestTheme(bg: {
            'kind': 'color',
            'gradient': null,
            'image': null,
            'dim': 0.45
          }));
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, const Color(0xFFF8F9FA));
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBodyBehindAppBar,
          isFalse);
      await leave(tester);
    });

    test('the look: the gradient\'s top colour, its text readable', () {
      LiveLook at(int angle) => LiveLook.from(
          LiveThemeState.fromJson(themed(devfestTheme(angle: angle))));
      expect(at(180).bar, const Color(0xFFFFFFFF), reason: 'to the bottom');
      expect(at(0).bar, const Color(0xFFE8F0FE), reason: 'to the top');
      expect(at(180).barOverBackdrop, isTrue);
      expect(liveContrast(at(180).onBar!, const Color(0xFFE8F0FE)),
          greaterThanOrEqualTo(liveTextContrast));
      expect(LiveLook.standard.barOverBackdrop, isFalse);
    });
  });
}
