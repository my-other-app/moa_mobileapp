import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/utils/question_answers.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';

AdditionalDetail _q(String key, String label, String type,
        {bool required = true, List<String> options = const []}) =>
    AdditionalDetail(
      key: key,
      label: label,
      fieldType: type,
      requiredField: required,
      options: options,
    );

final _questions = [
  _q('dob', 'Date of birth', 'date'),
  _q('arrival', 'Arrival', 'time', required: false),
  _q('agree', 'Code of conduct', 'checkbox', options: ['I agree']),
  _q('meal', 'Meal', 'checkbox', options: ['Veg', 'Non-veg']),
  _q('track', 'Track', 'radio', options: ['AI', 'Web']),
  _q('size', 'T-shirt', 'select', required: false, options: ['S', 'M']),
];

/// Questions answered by typing, which the server checks for their type.
final _typed = [
  _q('age', 'Age', 'number'),
  _q('site', 'Website', 'url', required: false),
  _q('track', 'Track', 'radio', options: ['AI', 'Web']),
];

/// The form, pushed from a page that keeps what it was closed with.
Future<List<Object?>> _pump(WidgetTester tester,
    {List<AdditionalDetail>? questions}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final closedWith = <Object?>[];
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async =>
                closedWith.add(await context.push<Object?>('/form')),
            child: const Text('Open form'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/form',
      builder: (_, __) =>
          EventFormPage(eventId: 7, additionalDetails: questions ?? _questions),
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
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
  return closedWith;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets(
      'dates and times are picked; checkboxes are boxes, not a dropdown',
      (tester) async {
    await _pump(tester);

    expect(find.text('Pick a date'), findsOneWidget);
    expect(find.text('Pick a time'), findsOneWidget);
    // One "I agree" box, and a box for each meal.
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.byType(RadioListTile<String>), findsNWidgets(2));
    // Only the select question and the organisation are dropdowns.
    expect(find.byType(DropdownButtonFormField2<String>), findsOneWidget);

    // The heading is in the declared family.
    final heading =
        tester.widget<Text>(find.text('Hop on and fill out this form! 📝✨'));
    expect(heading.style?.fontFamily, 'BebasNeue');
  });

  testWidgets('required boxes and pickers are checked before sending',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Please pick date of birth'), findsOneWidget);
    expect(find.text('Please tick this box'), findsOneWidget);
    expect(find.text('Please choose meal'), findsOneWidget);
    expect(find.text('Please choose track'), findsOneWidget);
    expect(api.sent('POST', '/events/registration/7/register'), isEmpty);
  });

  testWidgets('sends the picked date as a date and one ticked option',
      (tester) async {
    api.on('POST', '/events/registration/7/register', {
      'event_id': 7,
      'event_name': 'Hack Night',
      'event_registration_id': 'reg-1',
      'pay_amount': 0,
      'ticket_id': 'T-1',
      'event_datetime': '2030-12-01T10:00:00Z',
      'full_name': 'Asha Menon',
    });
    await _pump(tester);

    await tester.tap(find.widgetWithText(TextFormField, 'Pick a date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    expect(find.text(dateLabel(today)), findsOneWidget);

    await tester.tap(find.text('I agree'));
    await tester.tap(find.text('Veg'));
    await tester.pump();
    await tester.tap(find.text('Non-veg'));
    await tester.tap(find.text('Web'));
    await tester.pump();

    // Ticking another meal unticks the first: the server keeps one.
    final ticked = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .where((c) => c.value == true)
        .length;
    expect(ticked, 2); // "I agree" and "Non-veg"

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final sent = api.sent('POST', '/events/registration/7/register').single;
    expect((sent.data as Map)['additional_details'], {
      'dob': dateAnswer(today),
      'agree': 'I agree',
      'meal': 'Non-veg',
      'track': 'Web',
    });
    expect(find.text('Registered!'), findsOneWidget);
  });

  Future<void> fillAndSend(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextFormField, 'Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree'));
    await tester.tap(find.text('Veg'));
    await tester.tap(find.text('AI'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('ALREADY_REGISTERED offers the ticket, and closes with it',
      (tester) async {
    api.on(
        'POST',
        '/events/registration/7/register',
        {
          'message': 'Already registered for this event',
          'error_code': 'ALREADY_REGISTERED',
        },
        status: 400);
    final closedWith = await _pump(tester);

    await fillAndSend(tester);

    expect(find.text("You're already registered"), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
    await tester.tap(find.text('View ticket'));
    await tester.pumpAndSettle();
    expect(closedWith, [RegistrationAction.viewTicket]);
  });

  testWidgets('"Event is full" without a code still reads as full',
      (tester) async {
    api.on(
        'POST', '/events/registration/7/register', {'message': 'Event is full'},
        status: 400);
    await _pump(tester);

    await fillAndSend(tester);

    expect(find.text('This event is full'), findsOneWidget);
    expect(find.text('View ticket'), findsNothing);
  });

  testWidgets('REGISTRATIONS_CLOSED says the event is not taking more',
      (tester) async {
    api.on(
        'POST',
        '/events/registration/7/register',
        {
          'message': "This event isn't taking more registrations right now.",
          'error_code': 'REGISTRATIONS_CLOSED',
        },
        status: 409);
    await _pump(tester);

    await fillAndSend(tester);

    expect(find.text("This event isn't taking more registrations right now."),
        findsOneWidget);
  });

  group('answers the server refuses (INVALID_ANSWERS)', () {
    void refuse(Map<String, String> errors, {String? message}) => api.on(
        'POST',
        '/events/registration/7/register',
        {
          'message': message ?? 'Check your answers: Age, Track.',
          'error_code': 'INVALID_ANSWERS',
          'errors': errors,
        },
        status: 400);

    Future<void> answerAndSend(WidgetTester tester) async {
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter age'), 'twenty');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter website'), 'my site');
      await tester.tap(find.text('AI'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('each reason is shown under its own question', (tester) async {
      refuse({
        'age': 'Enter a number.',
        'site': 'Enter a web address, like example.com.',
      }, message: 'Check your answers: Age, Website.');
      await _pump(tester, questions: _typed);

      await answerAndSend(tester);

      expect(find.text('Enter a number.'), findsOneWidget);
      expect(
          find.text('Enter a web address, like example.com.'), findsOneWidget);
      // No dialog to read and dismiss; the form stays open, and says what
      // the server said as a whole.
      expect(find.text("We couldn't register you"), findsNothing);
      expect(find.text('Check your answers: Age, Website.'), findsOneWidget);
      expect(find.text('Registered!'), findsNothing);

      // The reason under each question sits below that question's box.
      final ageBox =
          tester.getRect(find.widgetWithText(TextFormField, 'Enter age'));
      final ageReason = tester.getRect(find.text('Enter a number.'));
      final siteBox =
          tester.getRect(find.widgetWithText(TextFormField, 'Enter website'));
      expect(ageReason.top, greaterThanOrEqualTo(ageBox.bottom));
      expect(ageReason.bottom, lessThanOrEqualTo(siteBox.top));
    });

    testWidgets('changing an answer clears what was said about it, only it',
        (tester) async {
      refuse({
        'age': 'Enter a number.',
        'track': 'Invalid option selected',
      });
      await _pump(tester, questions: _typed);
      await answerAndSend(tester);
      expect(find.text('Invalid option selected'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter age'), '20');
      await tester.pump();
      expect(find.text('Enter a number.'), findsNothing);
      expect(find.text('Invalid option selected'), findsOneWidget);

      await tester.tap(find.text('Web'));
      await tester.pump();
      expect(find.text('Invalid option selected'), findsNothing);
    });

    testWidgets('sent again, the corrected answers go as typed',
        (tester) async {
      refuse({'age': 'Enter a number.'});
      api.on('POST', '/events/registration/7/register', {
        'event_id': 7,
        'event_name': 'Hack Night',
        'event_registration_id': 'reg-1',
        'pay_amount': 0,
        'ticket_id': 'T-1',
        'event_datetime': '2030-12-01T10:00:00Z',
        'full_name': 'Asha Menon',
      });
      await _pump(tester, questions: _typed);
      await answerAndSend(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter age'), '20');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', '/events/registration/7/register');
      expect((sent.last.data as Map)['additional_details'],
          {'age': '20', 'site': 'my site', 'track': 'AI'});
      expect(find.text('Registered!'), findsOneWidget);
    });

    testWidgets('a refusal that names no question on the form is a dialog',
        (tester) async {
      refuse({'additional_details': 'The answers are too long.'},
          message: 'The answers are too long.');
      await _pump(tester, questions: _typed);

      await answerAndSend(tester);

      expect(find.text("We couldn't register you"), findsOneWidget);
      expect(find.text('The answers are too long.'), findsOneWidget);
    });
  });

  group('invalidAnswersOf', () {
    ApiException refusal(Map<String, dynamic> body) =>
        ApiException.fromResponse(400, body);

    test('reads the reasons for the questions the form asks', () {
      final e = refusal({
        'message': 'Check your answers: Age.',
        'error_code': 'INVALID_ANSWERS',
        'errors': {'age': 'Enter a number.', 'other': 'Not asked here'},
      });

      expect(invalidAnswersOf(e, ['age', 'site']), {'age': 'Enter a number.'});
    });

    test('is null for any other refusal, or none it can place', () {
      expect(
          invalidAnswersOf(
              refusal({
                'message': 'Event is full',
                'error_code': 'EVENT_FULL',
                'errors': {'age': 'x'},
              }),
              ['age']),
          isNull);
      expect(
          invalidAnswersOf(
              refusal({
                'message': 'Too many answers: at most 50.',
                'error_code': 'INVALID_ANSWERS',
                'errors': {'additional_details': 'At most 50 answers.'},
              }),
              ['age']),
          isNull);
    });
  });
}
