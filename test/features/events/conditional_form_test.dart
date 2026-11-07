// The registration form with conditional questions
// (conditional-questions-contract.md §8), on the shared test form of §12:
// only what applies is shown, in order; what stops applying loses its
// answer, on screen and in what is sent; a follow-up appears without taking
// the focus, is announced, and doesn't animate under reduced motion.

import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/widgets/revealed_question.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'conditional_form_fixture.dart';
import 'events_fakes.dart';

const _register = '/events/registration/7/register';

const _registered = {
  'event_id': 7,
  'event_name': 'Hack Night',
  'event_registration_id': 'reg-1',
  'pay_amount': 0,
  'ticket_id': 'T-1',
  'event_datetime': '2030-12-01T10:00:00Z',
  'full_name': 'Asha Menon',
};

Future<void> _pump(
  WidgetTester tester, {
  List<AdditionalDetail>? questions,
  Widget? form,
  Size size = const Size(800, 3600),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.push<Object?>('/form'),
            child: const Text('Open form'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/form',
      builder: (_, __) =>
          form ??
          EventFormPage(eventId: 7, additionalDetails: questions ?? sharedForm()),
    ),
    GoRoute(
      path: '/events/registration-success',
      builder: (_, __) => const Scaffold(body: Text('Registered!')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
    ),
  ));
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

/// The label of the question [label] (followed by " *" when required).
Finder _question(String label) => find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final text = widget.data ?? widget.textSpan?.toPlainText();
      return text == label || text == '$label *';
    }, description: 'the question "$label"');

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Picks [option] from the dropdown whose hint is [hint].
Future<void> _select(WidgetTester tester, String hint, String option) async {
  await tester.ensureVisible(find.text(hint));
  await tester.tap(find.text(hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String hint, String text) async {
  final field = find.widgetWithText(TextFormField, hint);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

TextEditingController? _controllerOf(WidgetTester tester, String hint) =>
    tester.widget<TextFormField>(find.widgetWithText(TextFormField, hint))
        .controller;

Future<Map<dynamic, dynamic>> _send(RouteAdapter api, WidgetTester tester) async {
  await _tap(tester, 'Continue');
  return (api.sent('POST', _register).single.data as Map)['additional_details']
      as Map;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('first load: only the questions everyone answers',
      (tester) async {
    await _pump(tester);

    expect(_question('Are you working or a student?'), findsOneWidget);
    expect(_question('T-shirt size'), findsOneWidget);
    for (final hidden in [
      'College name',
      'Year of study',
      'Degree type',
      'PG specialisation',
      'Company',
      'Years of experience',
    ]) {
      expect(_question(hidden), findsNothing, reason: hidden);
    }
    // Both required, and marked so.
    expect(find.bySemanticsLabel('Are you working or a student?, required'),
        findsOneWidget);
    expect(find.bySemanticsLabel('T-shirt size, required'), findsOneWidget);
  });

  testWidgets('Student shows the student questions, in order, marked required',
      (tester) async {
    await _pump(tester);
    await _tap(tester, 'Student');

    final order = [
      'Are you working or a student?',
      'College name',
      'Year of study',
      'Degree type',
      'T-shirt size',
    ];
    final tops = [for (final l in order) tester.getTopLeft(_question(l)).dy];
    expect(tops, orderedEquals([...tops]..sort()));
    // required: false on the wire, required_when_shown: true -- required.
    expect(find.bySemanticsLabel('College name, required'), findsOneWidget);
    expect(find.bySemanticsLabel('Degree type, required'), findsOneWidget);
    expect(_question('PG specialisation'), findsNothing);
    expect(_question('Company'), findsNothing);

    // Nested: PG brings its own question.
    await _tap(tester, 'PG');
    expect(_question('PG specialisation'), findsOneWidget);
    expect(find.bySemanticsLabel('PG specialisation, required'),
        findsOneWidget);
  });

  testWidgets('Working shows the work questions and hides the student ones',
      (tester) async {
    await _pump(tester);
    await _tap(tester, 'Working');

    expect(_question('Company'), findsOneWidget);
    expect(_question('Years of experience'), findsOneWidget);
    expect(_question('College name'), findsNothing);
    expect(_question('Degree type'), findsNothing);
    expect(_question('PG specialisation'), findsNothing);
  });

  testWidgets('Student to Working drops the student answers, on screen and '
      'in what is sent', (tester) async {
    api.on('POST', _register, _registered);
    await _pump(tester);

    await _tap(tester, 'Student');
    await _type(tester, 'Enter college name', 'CET');
    await _select(tester, 'Select year of study', '2');
    await _tap(tester, 'PG');
    await _type(tester, 'Enter pg specialisation', 'Data science');

    await _tap(tester, 'Working');
    await _type(tester, 'Enter company', 'Acme');
    await _select(tester, 'Select years of experience', '3-5');
    await _select(tester, 'Select t-shirt size', 'M');

    // Back to Student: what was typed there is gone.
    await _tap(tester, 'Student');
    expect(_controllerOf(tester, 'Enter college name')!.text, isEmpty);
    expect(find.text('Select year of study'), findsOneWidget);
    expect(_question('PG specialisation'), findsNothing,
        reason: 'the degree type was cleared with the rest');
    // And Working again: so are the work answers.
    await _tap(tester, 'Working');
    expect(_controllerOf(tester, 'Enter company')!.text, isEmpty);
    await _type(tester, 'Enter company', 'Acme');
    await _select(tester, 'Select years of experience', '0-2');

    expect(await _send(api, tester), {
      'status': 'Working',
      'company': 'Acme',
      'experience': '0-2',
      'tshirt': 'M',
    });
    expect(find.text('Registered!'), findsOneWidget);
  });

  testWidgets('PG to UG drops only the PG answer', (tester) async {
    api.on('POST', _register, _registered);
    await _pump(tester);

    await _tap(tester, 'Student');
    await _type(tester, 'Enter college name', 'CET');
    await _select(tester, 'Select year of study', '4');
    await _tap(tester, 'PG');
    await _type(tester, 'Enter pg specialisation', 'Data science');
    await _tap(tester, 'UG');

    expect(_question('PG specialisation'), findsNothing);
    expect(_controllerOf(tester, 'Enter college name')!.text, 'CET');

    await _tap(tester, 'PG');
    expect(_controllerOf(tester, 'Enter pg specialisation')!.text, isEmpty);
    await _tap(tester, 'UG');
    await _select(tester, 'Select t-shirt size', 'L');

    expect(await _send(api, tester), {
      'status': 'Student',
      'college': 'CET',
      'year': '4',
      'degree_type': 'UG',
      'tshirt': 'L',
    });
  });

  testWidgets('a follow-up is required only while it is shown',
      (tester) async {
    api.on('POST', _register, _registered);
    await _pump(tester);

    await _tap(tester, 'Student');
    await _select(tester, 'Select t-shirt size', 'S');
    await _tap(tester, 'Continue');
    expect(find.text('Please enter college name'), findsOneWidget);
    expect(find.text('Please choose degree type'), findsOneWidget);
    expect(find.text('Please enter company'), findsNothing);
    expect(api.sent('POST', _register), isEmpty);

    // Working: the student questions, blank, don't stop it.
    await _tap(tester, 'Working');
    await _type(tester, 'Enter company', 'Acme');
    await _select(tester, 'Select years of experience', '5+');
    expect(await _send(api, tester), {
      'status': 'Working',
      'company': 'Acme',
      'experience': '5+',
      'tshirt': 'S',
    });
  });

  testWidgets("the server's reason is said under the question it names",
      (tester) async {
    api.on(
        'POST',
        _register,
        {
          'message': 'Check your answers: College name.',
          'error_code': 'INVALID_ANSWERS',
          'errors': {'college': 'Use the college\'s full name.'},
        },
        status: 400);
    await _pump(tester);

    await _tap(tester, 'Student');
    await _type(tester, 'Enter college name', 'C');
    await _select(tester, 'Select year of study', '1');
    await _tap(tester, 'UG');
    await _select(tester, 'Select t-shirt size', 'XL');
    await _tap(tester, 'Continue');

    expect(find.text("Use the college's full name."), findsOneWidget);
    final box =
        tester.getRect(find.widgetWithText(TextFormField, 'Enter college name'));
    final reason = tester.getRect(find.text("Use the college's full name."));
    final next = tester.getRect(_question('Year of study'));
    expect(reason.top, greaterThanOrEqualTo(box.bottom));
    expect(reason.bottom, lessThanOrEqualTo(next.top));
    expect(find.text('Check your answers: College name.'), findsOneWidget);
  });

  testWidgets('a refusal naming a hidden question is not pinned to it',
      (tester) async {
    api.on(
        'POST',
        _register,
        {
          'message': 'Check your answers.',
          'error_code': 'INVALID_ANSWERS',
          'errors': {'company': 'This field is required'},
        },
        status: 400);
    await _pump(tester);

    await _tap(tester, 'Student');
    await _type(tester, 'Enter college name', 'CET');
    await _select(tester, 'Select year of study', '1');
    await _tap(tester, 'UG');
    await _select(tester, 'Select t-shirt size', 'XL');
    await _tap(tester, 'Continue');

    // Said as a refusal, not under a question that isn't there.
    expect(_question('Company'), findsNothing);
    expect(find.text("We couldn't register you"), findsOneWidget);
  });

  testWidgets('a revealed question is announced and does not take the focus',
      (tester) async {
    final said = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility, (message) async {
      final map = message as Map;
      if (map['type'] == 'announce') {
        said.add((map['data'] as Map)['message'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility, null));
    await _pump(tester);

    await _tap(tester, 'Student');
    expect(said, ['3 new questions: College name, Year of study, Degree type.']);

    final college = find.descendant(
        of: find.widgetWithText(TextFormField, 'Enter college name'),
        matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(college).focusNode.hasFocus, isFalse);

    await _tap(tester, 'PG');
    expect(said.last, 'New question: PG specialisation.');
    await _tap(tester, 'Working');
    expect(said.last,
        '2 new questions: Company, Years of experience. 4 questions removed.');
  });

  testWidgets('a revealed question grows in, or with reduced motion is there',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Student'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    var growing = tester.widget<SizeTransition>(find.descendant(
        of: find.byType(RevealedQuestion).first,
        matching: find.byType(SizeTransition)));
    expect(growing.sizeFactor.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    growing = tester.widget<SizeTransition>(find.descendant(
        of: find.byType(RevealedQuestion).first,
        matching: find.byType(SizeTransition)));
    expect(growing.sizeFactor.value, 1);
  });

  testWidgets('with reduced motion a revealed question is simply there',
      (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.tap(find.text('Student'));
    await tester.pump();
    final sized = tester.widget<SizeTransition>(find.descendant(
        of: find.byType(RevealedQuestion).first,
        matching: find.byType(SizeTransition)));
    expect(sized.sizeFactor.value, 1);
  });

  testWidgets('320pt wide at twice the text size, nothing overflows',
      (tester) async {
    final longForm = [
      ...sharedForm(),
      AdditionalDetail.fromJson(const {
        'key': 'why',
        'label': 'Tell us in a sentence or two why you would like to attend '
            'this workshop and what you hope to learn',
        'field_type': 'textarea',
        'required': false,
        'required_when_shown': true,
        'show_if': {'key': 'degree_type', 'any_of': ['PG']},
      }),
    ];
    await _pump(tester,
        questions: longForm, size: const Size(320, 1400), textScale: 2);
    await _tap(tester, 'Student');
    await _tap(tester, 'PG');
    await tester.ensureVisible(find.textContaining('Tell us in a sentence'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The long label wraps onto more lines rather than running off.
    final label = tester.getRect(find.textContaining('Tell us in a sentence'));
    expect(label.right, lessThanOrEqualTo(320));
    expect(label.height, greaterThan(24 * 2));
  });

  testWidgets('read from /events/info, the wire shape works as handed over',
      (tester) async {
    api
      ..on('GET', '/events/info/hack-night', {
        'id': 7,
        'name': 'Hack Night',
        'has_fee': false,
        'is_online': false,
        'additional_details': sharedFormJson,
      })
      ..on('POST', _register, _registered);
    await _pump(tester, form: const EventFormPage(eventRef: 'hack-night'));

    expect(_question('College name'), findsNothing);
    await _tap(tester, 'Working');
    await _type(tester, 'Enter company', 'Acme');
    await _select(tester, 'Select years of experience', '0-2');
    await _select(tester, 'Select t-shirt size', 'M');
    expect(await _send(api, tester), {
      'status': 'Working',
      'company': 'Acme',
      'experience': '0-2',
      'tshirt': 'M',
    });
  });

  testWidgets('an unconditional form is unchanged: every question, as sent',
      (tester) async {
    api.on('POST', _register, _registered);
    final plain = [
      AdditionalDetail.fromJson(const {
        'key': 'college',
        'label': 'College',
        'field_type': 'text',
        'required': true,
      }),
      AdditionalDetail.fromJson(const {
        'key': 'size',
        'label': 'Size',
        'field_type': 'select',
        'required': false,
        'options': ['S', 'M'],
      }),
    ];
    await _pump(tester, questions: plain);
    expect(find.byType(RevealedQuestion), findsNothing);
    expect(find.bySemanticsLabel('College, required'), findsOneWidget);
    expect(find.bySemanticsLabel('Size'), findsOneWidget);

    await _tap(tester, 'Continue');
    expect(find.text('Please enter college'), findsOneWidget);
    await _type(tester, 'Enter college', 'CET');
    await _select(tester, 'Select size', 'M');
    expect(await _send(api, tester), {'college': 'CET', 'size': 'M'});
  });
}
