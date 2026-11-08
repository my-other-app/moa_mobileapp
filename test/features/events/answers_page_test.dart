// The missing-answers screen (missing-answers-contract.md §2.3, §3 App 1), on
// the shared conditional form (conditional-questions-contract.md §12): only
// the questions asked, with the follow-ups their answers bring, filled in
// with what the person has, checked as registration checks them; and every
// state instead of the form.

import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/answers_page.dart';
import 'package:finnet/features/events/presentation/widgets/revealed_question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'conditional_form_fixture.dart';
import 'events_fakes.dart';

const _path = '/events/7/answers/reg-1';
const _ticket = 'https://myotherapp.in/tickets/MOA-ABCDE-12345';

/// `GET /events/7/answers/reg-1?k=…`, as the contract has it.
Map<String, dynamic> _body({
  String status = 'open',
  List<String> asked = const ['year', 'degree_type'],
  Map<String, Object?> answers = const {'status': 'Student', 'college': 'CET'},
  String? ticketUrl = _ticket,
  String? requestUrl,
  String kind = 'registration',
}) =>
    {
      'status': status,
      'event': {
        'id': 7,
        'name': 'Hack Night',
        'starts_at': '2030-12-01T10:00:00Z',
        'org_name': 'Tinkerhub',
        'poster': null,
        'slug': 'hack-night-ab12cd',
      },
      'person': {'first_name': 'Haritha', 'kind': kind},
      'deadline': '2030-11-28T12:30:00Z',
      'message': 'We need 2 more details for your Hack Night ticket.',
      'questions': status == 'nothing' ? const [] : sharedFormJson,
      'asked': asked,
      'answers': answers,
      'ticket_url': ticketUrl,
      'request_url': requestUrl,
    };

/// The label of the question [label] (followed by " *" when required).
Finder _question(String label) => find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final text = widget.data ?? widget.textSpan?.toPlainText();
      return text == label || text == '$label *';
    }, description: 'the question "$label"');

Future<void> _pump(
  WidgetTester tester, {
  String location = '/answers/7/reg-1?k=abc.def',
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(
      path: '/answers/:eventId/:ref',
      builder: (_, state) => AnswersPage(
        eventId: int.parse(state.pathParameters['eventId']!),
        personRef: state.pathParameters['ref']!,
        linkKey: state.uri.queryParameters['k'] ?? '',
      ),
    ),
    GoRoute(
      path: '/tickets/:code',
      builder: (_, state) =>
          Scaffold(body: Text('ticket ${state.pathParameters['code']}')),
    ),
    GoRoute(
      path: '/requests/:token',
      builder: (_, state) =>
          Scaffold(body: Text('request ${state.pathParameters['token']}')),
    ),
    GoRoute(
      path: '/events/:ref',
      builder: (_, state) =>
          Scaffold(body: Text('event ${state.pathParameters['ref']}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [isAuthenticatedProvider.overrideWithValue(signedIn)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String hint, String option) async {
  await _tap(tester, find.text(hint));
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) =>
    _tap(tester, find.byKey(AnswersPage.saveKey));

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('the form', () {
    testWidgets(
        'only the questions asked, with the event, the message and the '
        'deadline, filled in with what they have', (tester) async {
      api.on('GET', _path,
          _body(answers: {'status': 'Student', 'college': 'CET', 'year': 2}));
      await _pump(tester);

      expect(find.text('Hack Night'), findsOneWidget);
      expect(find.text('Tinkerhub'), findsOneWidget);
      expect(find.text('Hi Haritha, Tinkerhub needs 2 more details'),
          findsOneWidget);
      expect(find.text('We need 2 more details for your Hack Night ticket.'),
          findsOneWidget);
      expect(find.textContaining('Add them by '), findsOneWidget);

      expect(_question('Year of study'), findsOneWidget);
      expect(_question('Degree type'), findsOneWidget);
      // Asked of nobody here: not shown, though answered or required.
      for (final hidden in [
        'Are you working or a student?',
        'College name',
        'PG specialisation',
        'Company',
        'T-shirt size',
      ]) {
        expect(_question(hidden), findsNothing, reason: hidden);
      }
      // Required, as the club set it (required_when_shown).
      expect(find.bySemanticsLabel('Degree type, required'), findsOneWidget);
      // Their year, filled in.
      expect(find.text('2'), findsOneWidget);

      // The link's key goes, and no session.
      final get = api.sent('GET', _path).single;
      expect(get.queryParameters, {'k': 'abc.def'});
      expect(get.extra['skipAuth'], isTrue);
    });

    testWidgets(
        'a follow-up an answer brings is asked too, checked, and sent; then '
        'the thanks and the ticket', (tester) async {
      api
        ..on('GET', _path, _body())
        ..on('POST', _path, _body(status: 'done', asked: const []));
      await _pump(tester);

      await _select(tester, 'Select year of study', '3');
      await _tap(tester, find.text('PG'));
      // Nested: PG brings its own question, revealed beneath.
      expect(_question('PG specialisation'), findsOneWidget);
      expect(find.byType(RevealedQuestion), findsOneWidget);

      // Required when shown: not sent blank.
      await _save(tester);
      expect(find.text('Please enter pg specialisation'), findsOneWidget);
      expect(api.sent('POST', _path), isEmpty);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter pg specialisation'),
          'Data science');
      await _save(tester);

      final post = api.sent('POST', _path).single;
      expect(post.queryParameters, {'k': 'abc.def'});
      expect(post.extra['skipAuth'], isTrue);
      // Only what is on screen: never their college or status.
      expect(post.data, {
        'answers': {
          'year': '3',
          'degree_type': 'PG',
          'pg_spec': 'Data science',
        },
      });
      expect(find.byKey(AnswersPage.thanksKey), findsOneWidget);
      expect(find.text(AnswersPage.thanksTitle), findsOneWidget);

      await _tap(tester, find.byKey(AnswersPage.viewTicketKey));
      expect(find.text('ticket MOA-ABCDE-12345'), findsOneWidget);
    });

    testWidgets('switching a parent drops the follow-up it brought',
        (tester) async {
      api
        ..on('GET', _path, _body(asked: const ['degree_type']))
        ..on('POST', _path, _body(status: 'done', asked: const []));
      await _pump(tester);

      await _tap(tester, find.text('PG'));
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter pg specialisation'),
          'Data science');
      await _tap(tester, find.text('UG'));
      expect(_question('PG specialisation'), findsNothing);

      await _save(tester);
      expect(api.sent('POST', _path).single.data, {
        'answers': {'degree_type': 'UG'},
      });
    });

    testWidgets('a choice the club has since removed is asked again',
        (tester) async {
      api.on(
          'GET',
          _path,
          _body(
            asked: const ['tshirt'],
            answers: const {'status': 'Working', 'tshirt': 'XXL'},
          ));
      await _pump(tester);

      expect(find.text('Hi Haritha, Tinkerhub needs 1 more detail'),
          findsOneWidget);
      expect(find.text('Select t-shirt size'), findsOneWidget);
      await _save(tester);
      expect(find.text('Please select t-shirt size'), findsOneWidget);
      expect(api.sent('POST', _path), isEmpty);
    });

    testWidgets('a refused answer is said under its question', (tester) async {
      api
        ..on('GET', _path,
            _body(asked: const ['company'], answers: {'status': 'Working'}))
        ..on(
            'POST',
            _path,
            {
              'message': 'Check your answers.',
              'error_code': 'INVALID_ANSWERS',
              'errors': {'company': 'That is too long.', 'other': 'Ignored'},
            },
            status: 422);
      await _pump(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter company'), 'Acme');
      await _save(tester);

      expect(find.text('That is too long.'), findsOneWidget);
      expect(find.text('Ignored'), findsNothing);
      expect(find.byKey(AnswersPage.formKey), findsOneWidget);
    });

    testWidgets('after the deadline it says the asking has closed',
        (tester) async {
      api
        ..on('GET', _path,
            _body(asked: const ['company'], answers: {'status': 'Working'}))
        ..on('POST', _path,
            {'message': 'This has closed.', 'error_code': 'CLOSED'},
            status: 409);
      await _pump(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter company'), 'Acme');
      await _save(tester);

      expect(find.byKey(AnswersPage.closedKey), findsOneWidget);
      expect(find.byKey(AnswersPage.viewTicketKey), findsOneWidget);
    });

    testWidgets('more still asked after saving: the rest can be added',
        (tester) async {
      api
        ..on('GET', _path,
            _body(asked: const ['company'], answers: {'status': 'Working'}))
        ..on(
            'POST',
            _path,
            _body(
                asked: const ['tshirt'],
                answers: {'status': 'Working', 'company': 'Acme'}));
      await _pump(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter company'), 'Acme');
      await _save(tester);
      expect(find.text('There is 1 more detail to add.'), findsOneWidget);

      await _tap(tester, find.byKey(AnswersPage.moreKey));
      expect(_question('T-shirt size'), findsOneWidget);
      expect(_question('Company'), findsNothing);
    });
  });

  group('instead of the form', () {
    testWidgets('nothing left to add', (tester) async {
      api.on('GET', _path, _body(status: 'done', asked: const []));
      await _pump(tester);
      expect(find.byKey(AnswersPage.doneKey), findsOneWidget);
      expect(find.text("You're all set"), findsOneWidget);
      expect(find.byKey(AnswersPage.viewTicketKey), findsOneWidget);
    });

    testWidgets('the deadline passed', (tester) async {
      api.on('GET', _path, _body(status: 'closed'));
      await _pump(tester);
      expect(find.byKey(AnswersPage.closedKey), findsOneWidget);
      expect(find.byKey(AnswersPage.saveKey), findsNothing);
    });

    testWidgets('a registration that no longer counts', (tester) async {
      api.on('GET', _path,
          _body(status: 'nothing', asked: const [], answers: const {}));
      await _pump(tester);
      expect(find.byKey(AnswersPage.nothingKey), findsOneWidget);
      expect(find.byKey(AnswersPage.viewTicketKey), findsNothing);
      // The event is still there to open.
      await _tap(tester, find.text('View event'));
      expect(find.text('event hack-night-ab12cd'), findsOneWidget);
    });

    testWidgets('a registration under review offers its own page',
        (tester) async {
      api.on(
          'GET',
          '/events/7/answers/qreq-1',
          _body(
            status: 'done',
            asked: const [],
            kind: 'request',
            ticketUrl: null,
            requestUrl: 'https://myotherapp.in/requests/tok-1',
          ));
      await _pump(tester, location: '/answers/7/qreq-1?k=s');

      await _tap(tester, find.byKey(AnswersPage.viewRequestKey));
      expect(find.text('request tok-1'), findsOneWidget);
    });

    testWidgets('a link that does not work says so', (tester) async {
      api.on('GET', _path, {'message': 'Not found'}, status: 404);
      await _pump(tester);
      expect(find.byKey(AnswersPage.invalidKey), findsOneWidget);
      expect(find.text(AnswersPage.invalidLink), findsOneWidget);
      expect(find.byKey(AnswersPage.signInKey), findsNothing);
    });

    testWidgets('a failure to load can be tried again', (tester) async {
      api
        ..on('GET', _path, {'message': 'Down'}, status: 503)
        ..on('GET', _path, _body());
      await _pump(tester);
      expect(find.byKey(AnswersPage.retryKey), findsOneWidget);

      await _tap(tester, find.byKey(AnswersPage.retryKey));
      expect(find.byKey(AnswersPage.formKey), findsOneWidget);
    });
  });

  group('without the link\'s key', () {
    testWidgets('signed out: sign in, and nothing is asked of the server',
        (tester) async {
      await _pump(tester, location: '/answers/7/reg-1');
      expect(find.byKey(AnswersPage.invalidKey), findsOneWidget);
      expect(find.byKey(AnswersPage.signInKey), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('signed in: their own session is the proof', (tester) async {
      api.on('GET', _path, _body());
      await _pump(tester, location: '/answers/7/reg-1', signedIn: true);

      final get = api.sent('GET', _path).single;
      expect(get.queryParameters, isEmpty);
      expect(get.extra['skipAuth'], isFalse);
      expect(find.byKey(AnswersPage.formKey), findsOneWidget);
    });
  });
}
