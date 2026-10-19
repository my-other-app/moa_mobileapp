import 'package:finnet/features/events/data/datasources/feedback_survey_datasource.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/presentation/pages/feedback_survey_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

const _reg = '6f1c2d4e-0000-4000-8000-000000000001';
const _path = '/events/7/feedback/$_reg';

/// `GET /events/7/feedback/{reg}?k=…`, as production sends it.
Map<String, dynamic> _survey({bool submitted = false}) => {
      'event_name': 'Hack Night',
      'club_name': 'Tinkerhub',
      'first_name': 'Asha',
      'submitted': submitted,
      'questions': [
        {'key': 'overall', 'kind': 'rating', 'label': 'How was it overall?'},
        {
          'key': 'recommend',
          'kind': 'nps',
          'label': 'Would you recommend it to a friend?',
        },
        {'key': 'better', 'kind': 'text', 'label': 'What could be better?'},
        {'key': 'odd', 'kind': 'poll', 'label': 'Not a kind this app knows'},
      ],
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(WidgetTester tester, {String key = 'abc.def'}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home:
          FeedbackSurveyPage(eventId: 7, registrationId: _reg, surveyKey: key),
    ),
  ));
  await _settle(tester);
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  test('FeedbackSurvey skips questions of a kind it does not know', () {
    final survey = FeedbackSurvey.fromJson(_survey());
    expect(survey.questions.map((q) => q.kind),
        [SurveyKind.rating, SurveyKind.nps, SurveyKind.text]);
    expect(FeedbackSurvey.fromJson(const {}).questions, isEmpty);
  });

  test('a survey link from the email is a route in the app', () {
    expect(
        feedbackRouteFrom('https://myotherapp.in/feedback/7/$_reg?k=abc.def'),
        '/feedback/7/$_reg?k=abc.def');
    expect(feedbackRouteFrom('https://evil.example/feedback/7/x?k=1'), isNull);
    expect(feedbackRouteFrom('https://myotherapp.in/events/7'), isNull);
    expect(feedbackRouteFrom('not a link'), isNull);
  });

  testWidgets('answered here, with the key, and no account', (tester) async {
    api
      ..on('GET', _path, _survey())
      ..on('POST', _path, {'submitted': true});
    await _pump(tester);

    expect(find.text('How was Hack Night?'), findsOneWidget);
    expect(find.text('How was it overall?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('survey-overall-4')));
    await tester.tap(find.byKey(const ValueKey('survey-recommend-9')));
    await tester.enterText(
        find.byKey(const ValueKey('survey-better')), '  More snacks  ');
    await tester.tap(find.text('Send'));
    await _settle(tester);

    final get = api.sent('GET', _path).single;
    expect(get.queryParameters, {'k': 'abc.def'});
    expect(get.extra['skipAuth'], isTrue);
    final post = api.sent('POST', _path).single;
    expect(post.queryParameters, {'k': 'abc.def'});
    expect(post.data, {
      'answers': {'overall': 4, 'recommend': 9, 'better': 'More snacks'},
    });
    expect(find.text('Thank you, Asha.'), findsOneWidget);
    expect(find.text('Tinkerhub read every reply.'), findsOneWidget);
  });

  testWidgets('nothing answered: nothing sent', (tester) async {
    api.on('GET', _path, _survey());
    await _pump(tester);

    await tester.tap(find.text('Send'));
    await _settle(tester);
    expect(find.text('Answer at least one question.'), findsOneWidget);
    expect(api.sent('POST', _path), isEmpty);
  });

  testWidgets('answered before: the thanks', (tester) async {
    api.on('GET', _path, _survey(submitted: true));
    await _pump(tester);
    expect(find.text('Thank you, Asha.'), findsOneWidget);
  });

  testWidgets('a link that does not work says so', (tester) async {
    api.on('GET', _path, {'message': 'This feedback link is not valid.'},
        status: 404);
    await _pump(tester);
    expect(find.text("This link doesn't work. Open the one from your email."),
        findsOneWidget);
  });

  testWidgets('no key: nothing asked', (tester) async {
    await _pump(tester, key: '');
    expect(find.text("This link doesn't work. Open the one from your email."),
        findsOneWidget);
    expect(api.requests, isEmpty);
  });
}
