import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:finnet/app/router/tracking_ref.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/clubs/domain/club_updates.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/utils/question_answers.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/foundation.dart';
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
    {List<AdditionalDetail>? questions,
    Widget? form,
    bool signedIn = true}) async {
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
          form ??
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
      isAuthenticatedProvider.overrideWithValue(signedIn),
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
    // One "I agree" box, a box for each meal, and "Send my ticket on
    // WhatsApp" under the phone number.
    expect(find.byType(CheckboxListTile), findsNWidgets(4));
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
      // Answers that pass the form's own checks; the server refuses them
      // for reasons of its own.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter age'), '21');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter website'), 'example.com');
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
          {'age': '20', 'site': 'example.com', 'track': 'AI'});
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

  group('each kind of question the website asks', () {
    final typed = [
      _q('mail', 'Work email', 'email'),
      _q('site', 'Portfolio', 'url'),
      _q('tel', 'Alternate phone', 'tel'),
      _q('age', 'Age', 'number'),
      _q('bio', 'About you', 'textarea'),
      _q('start', 'Start', 'datetime', required: false),
      _q('file', 'Resume link', 'file', required: false),
    ];

    testWidgets('every type has a control: none is left invisible',
        (tester) async {
      await _pump(tester, questions: typed);

      for (final label in [
        'Enter work email',
        'Enter portfolio',
        'Enter alternate phone',
        'Enter age',
        'Enter about you',
        'Enter resume link',
      ]) {
        expect(find.widgetWithText(TextFormField, label), findsOneWidget,
            reason: label);
      }
      expect(find.text('Pick a date and time'), findsOneWidget);
    });

    testWidgets('a typo is caught here, in the server\'s words, before sending',
        (tester) async {
      await _pump(tester, questions: typed);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter work email'), 'asha@');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter portfolio'), 'my site');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter alternate phone'), '12ab');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter age'), 'twenty');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter about you'), 'Builder');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an email address, like name@example.com.'),
          findsOneWidget);
      expect(
          find.text('Enter a web address, like example.com.'), findsOneWidget);
      expect(find.text('Enter a phone number.'), findsOneWidget);
      expect(find.text('Enter a number.'), findsOneWidget);
      expect(api.sent('POST', '/events/registration/7/register'), isEmpty);
    });

    test('typedAnswerProblem matches the website', () {
      expect(typedAnswerProblem('email', 'a@b.co'), isNull);
      expect(typedAnswerProblem('url', 'example.com/x'), isNull);
      expect(typedAnswerProblem('url', 'https://example.com'), isNull);
      expect(typedAnswerProblem('tel', '+91 98765-43210'), isNull);
      expect(typedAnswerProblem('number', '4,5'), isNull);
      expect(typedAnswerProblem('number', '-3'), isNull);
      expect(typedAnswerProblem('text', 'anything'), isNull);
      expect(typedAnswerProblem('email', ''), isNull);
      expect(typedAnswerProblem('url', 'not a url'), isNotNull);
    });
  });

  group('opened from a link', () {
    testWidgets('by slug, it reads the event for its id and questions',
        (tester) async {
      api
        ..on('GET', '/events/info/hack-night', {
          'id': 7,
          'name': 'Hack Night',
          'has_fee': false,
          'is_online': false,
          'additional_details': [
            {
              'key': 'college',
              'label': 'College',
              'field_type': 'text',
              'required': true,
            },
          ],
        })
        ..on('POST', '/events/registration/7/register', {
          'event_id': 7,
          'event_name': 'Hack Night',
          'event_registration_id': 'reg-1',
          'pay_amount': 0,
          'ticket_id': 'T-1',
        });
      await _pump(tester, form: const EventFormPage(eventRef: 'hack-night'));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter college'), 'CET');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', '/events/registration/7/register').single;
      expect((sent.data as Map)['additional_details'], {'college': 'CET'});
      expect(find.text('Registered!'), findsOneWidget);
    });

    testWidgets('an event that cannot load says so, with a retry',
        (tester) async {
      await _pump(tester, form: const EventFormPage(eventRef: 'gone'));
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);
    });
  });

  testWidgets('signed out, the form asks for an account and sends nothing',
      (tester) async {
    await _pump(tester, signedIn: false);

    expect(find.text('Sign in to register'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sign-in-prompt')), findsOneWidget);
  });

  group('a paid online event', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('on ${platform.name}', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await _pump(tester,
            form: EventFormPage(
              eventId: 7,
              additionalDetails: const [],
              hasFee: true,
              isOnline: true,
            ));

        if (platform == TargetPlatform.iOS) {
          expect(find.text(iosOnlineSaleBlockedMessage), findsOneWidget);
          expect(find.text('Continue'), findsNothing);
        } else {
          expect(find.text(iosOnlineSaleBlockedMessage), findsNothing);
          expect(find.text('Continue'), findsOneWidget);
        }
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('on iOS, opened from a link, it is read before the form shows',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      api.on('GET', '/events/info/7', {
        'id': 7,
        'has_fee': true,
        'is_online': true,
        'additional_details': const [],
      });
      await _pump(tester,
          form: EventFormPage(eventId: 7, additionalDetails: const []));

      expect(find.text(iosOnlineSaleBlockedMessage), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('merch picks', () {
    const catalog = {
      'enabled': true,
      'items': [
        {'id': 'tee', 'name': 'Hack Night tee', 'price': 399, 'variants': []},
      ],
    };
    void registered() => api.on('POST', '/events/registration/7/register', {
          'event_id': 7,
          'event_name': 'Hack Night',
          'event_registration_id': 'reg-1',
          'pay_amount': 0,
          'ticket_id': 'T-1',
          'event_datetime': '2030-12-01T10:00:00Z',
          'full_name': 'Asha Menon',
        });

    testWidgets('an event with merch sends the picks even when there are none',
        (tester) async {
      api.on('GET', '/events/7/store/catalog', catalog);
      registered();
      await _pump(tester);
      await fillAndSend(tester);

      final sent = api.sent('POST', '/events/registration/7/register').single;
      // An empty list, not a missing key: it drops an earlier order.
      expect((sent.data as Map)['store'], isEmpty);
      expect((sent.data as Map).containsKey('store'), isTrue);
    });

    testWidgets('an event without merch sends no store at all', (tester) async {
      api.on('GET', '/events/7/store/catalog', {'enabled': false, 'items': []});
      registered();
      await _pump(tester);
      await fillAndSend(tester);

      final sent = api.sent('POST', '/events/registration/7/register').single;
      expect((sent.data as Map).containsKey('store'), isFalse);
    });
  });

  group('Get updates from the club on WhatsApp', () {
    const label = 'Get updates from Robotics Club on WhatsApp';
    final box = find.byKey(const ValueKey('register-club-updates'));
    final phone = find.byKey(const ValueKey('register-phone'));
    const offering = EventFormPage(
      eventId: 7,
      additionalDetails: [],
      clubName: 'Robotics Club',
      offersClubUpdates: true,
    );
    void registered() => api.on('POST', '/events/registration/7/register', {
          'event_id': 7,
          'event_name': 'Hack Night',
          'event_registration_id': 'reg-1',
          'pay_amount': 0,
          'ticket_id': 'T-1',
          'club_updates_whatsapp': true,
        });
    Map<dynamic, dynamic> sentBody() =>
        api.sent('POST', '/events/registration/7/register').single.data as Map;
    Future<void> send(WidgetTester tester) async {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('a club without the flag: no box, and nothing extra is sent',
        (tester) async {
      registered();
      await _pump(tester,
          form: const EventFormPage(eventId: 7, additionalDetails: []));

      expect(box, findsNothing);
      expect(find.textContaining('Get updates from'), findsNothing);
      await send(tester);
      expect(sentBody().containsKey('club_updates_whatsapp'), isFalse);
      expect(find.text('Registered!'), findsOneWidget);
    });

    testWidgets(
        'names the club under the phone number, unticked; ticked, '
        'it goes with the registration', (tester) async {
      registered();
      await _pump(tester, form: offering);

      expect(find.text(label), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(box).value, isFalse);
      expect(
          tester.getTopLeft(box).dy, greaterThan(tester.getTopLeft(phone).dy));

      await tester.tap(box);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(box).value, isTrue);
      await send(tester);

      expect(sentBody()['club_updates_whatsapp'], isTrue);
      expect(sentBody()['phone'], '9876543210');
      expect(find.text('Registered!'), findsOneWidget);
    });

    testWidgets('left unticked, the registration is sent as it always was',
        (tester) async {
      registered();
      await _pump(tester, form: offering);

      await send(tester);

      expect(sentBody().containsKey('club_updates_whatsapp'), isFalse);
    });

    testWidgets('ticked, it wants a mobile number WhatsApp can reach',
        (tester) async {
      registered();
      await _pump(tester, form: offering);
      await tester.enterText(phone, '5876543210');
      await tester.tap(box);
      await tester.pump();

      await send(tester);
      expect(
          find.text(
              'WhatsApp needs a mobile number. Or untick the WhatsApp box.'),
          findsOneWidget);
      expect(api.sent('POST', '/events/registration/7/register'), isEmpty);

      // Unticked, any ten digits will do, as before.
      await tester.tap(box);
      await tester.pump();
      await send(tester);
      expect(sentBody().containsKey('club_updates_whatsapp'), isFalse);
    });

    testWidgets("the server's WHATSAPP_NUMBER is said under the phone number",
        (tester) async {
      api.on(
          'POST',
          '/events/registration/7/register',
          {
            'message': "To get the club's updates on WhatsApp, enter a mobile "
                'number WhatsApp can reach, or untick the box.',
            'error_code': 'WHATSAPP_NUMBER',
            'errors': {'phone': "WhatsApp can't reach this number: no."},
          },
          status: 422);
      await _pump(tester, form: offering);
      await tester.tap(box);
      await tester.pump();

      await send(tester);

      expect(find.text(whatsappNumberProblem), findsOneWidget);
      // Said in place, not as a dialog.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Registered!'), findsNothing);

      // Changing the number clears it.
      await tester.enterText(phone, '9876543211');
      await tester.pump();
      expect(find.text(whatsappNumberProblem), findsNothing);
    });

    group('opened from a link', () {
      Map<String, dynamic> info({bool? whatsappUpdates}) => {
            'id': 7,
            'name': 'Hack Night',
            'has_fee': false,
            'is_online': false,
            'additional_details': const [],
            'club': {
              'id': 3,
              'name': 'Robotics Club',
              'slug': 'robotics-club',
              'logo': null,
              if (whatsappUpdates != null) 'whatsapp_updates': whatsappUpdates,
            },
          };

      testWidgets("the event's own club says it is offered", (tester) async {
        api.on('GET', '/events/info/hack-night', info(whatsappUpdates: true));
        await _pump(tester, form: const EventFormPage(eventRef: 'hack-night'));

        expect(find.text(label), findsOneWidget);
      });

      testWidgets('what the form reads wins over what it was handed',
          (tester) async {
        api.on('GET', '/events/info/hack-night', info(whatsappUpdates: false));
        await _pump(tester,
            form: const EventFormPage(
                eventRef: 'hack-night',
                clubName: 'Robotics Club',
                offersClubUpdates: true));

        expect(find.text('Continue'), findsOneWidget);
        expect(box, findsNothing);
      });

      testWidgets('a server without the flag shows no box', (tester) async {
        api.on('GET', '/events/info/hack-night', info());
        await _pump(tester, form: const EventFormPage(eventRef: 'hack-night'));

        expect(find.text('Continue'), findsOneWidget);
        expect(box, findsNothing);
      });
    });
  });

  group('Send my ticket and event reminders on WhatsApp', () {
    final box = find.byKey(const ValueKey('register-whatsapp'));
    final phone = find.byKey(const ValueKey('register-phone'));
    const form = EventFormPage(eventId: 7, additionalDetails: []);
    void registered() => api.on('POST', '/events/registration/7/register', {
          'event_id': 7,
          'event_name': 'Hack Night',
          'event_registration_id': 'reg-1',
          'pay_amount': 0,
          'ticket_id': 'T-1',
          'whatsapp_opt_in': true,
        });
    Map<dynamic, dynamic> sentBody() =>
        api.sent('POST', '/events/registration/7/register').single.data as Map;
    Future<void> send(WidgetTester tester) async {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('is under the phone number, in the website\'s words, unticked',
        (tester) async {
      registered();
      await _pump(tester, form: form);

      expect(find.text(whatsappTicketsText), findsOneWidget);
      expect(whatsappTicketsText,
          'Send my ticket and event reminders on WhatsApp');
      expect(tester.widget<CheckboxListTile>(box).value, isFalse);
      expect(
          tester.getTopLeft(box).dy, greaterThan(tester.getTopLeft(phone).dy));
    });

    testWidgets('left unticked, nothing about WhatsApp is sent',
        (tester) async {
      registered();
      await _pump(tester, form: form);

      await send(tester);

      expect(sentBody().containsKey('whatsapp_opt_in'), isFalse);
      expect(find.text('Registered!'), findsOneWidget);
    });

    testWidgets('ticked, whatsapp_opt_in goes with the registration',
        (tester) async {
      registered();
      await _pump(tester, form: form);

      await tester.tap(box);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(box).value, isTrue);
      await send(tester);

      expect(sentBody()['whatsapp_opt_in'], isTrue);
      expect(sentBody()['phone'], '9876543210');
      expect(find.text('Registered!'), findsOneWidget);
    });

    testWidgets('ticked, it wants a mobile number WhatsApp can reach',
        (tester) async {
      registered();
      await _pump(tester, form: form);
      await tester.enterText(phone, '5876543210');
      await tester.tap(box);
      await tester.pump();

      await send(tester);

      expect(
          find.text(
              'WhatsApp needs a mobile number. Or untick the WhatsApp box.'),
          findsOneWidget);
      expect(api.sent('POST', '/events/registration/7/register'), isEmpty);

      // Unticked, the same number registers.
      await tester.tap(box);
      await tester.pump();
      await send(tester);
      expect(sentBody().containsKey('whatsapp_opt_in'), isFalse);
    });

    testWidgets("the server's 422 WHATSAPP_NUMBER is said under the phone",
        (tester) async {
      // As registration/service.py refuses it (backend #100).
      api.on(
          'POST',
          '/events/registration/7/register',
          {
            'message': 'To get your ticket on WhatsApp, enter a mobile number '
                'WhatsApp can reach, or untick the box.',
            'error_code': 'WHATSAPP_NUMBER',
            'errors': {'phone': "WhatsApp can't reach this number: no."},
          },
          status: 422);
      await _pump(tester, form: form);
      await tester.tap(box);
      await tester.pump();

      await send(tester);

      expect(find.text(whatsappNumberProblem), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Registered!'), findsNothing);

      // Unticking the box clears it.
      await tester.tap(box);
      await tester.pump();
      expect(find.text(whatsappNumberProblem), findsNothing);
    });
  });

  group("a club's tracking link", () {
    tearDown(() => TrackingRef.instance = TrackingRef());

    void registered() => api.on('POST', '/events/registration/7/register', {
          'event_id': 7,
          'event_name': 'Hack Night',
          'event_registration_id': 'reg-1',
          'pay_amount': 0,
          'ticket_id': 'T-1',
        });

    testWidgets('that opened the app is credited with the registration',
        (tester) async {
      TrackingRef.instance.remember(
          Uri.parse('/events/hack-night?ref=QR7poster&via=l'));
      registered();
      await _pump(tester,
          form: const EventFormPage(eventId: 7, additionalDetails: []));

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final body = api
          .sent('POST', '/events/registration/7/register')
          .single
          .data as Map;
      expect(body['ref'], 'qr7poster');
    });

    testWidgets('none held: no ref is sent', (tester) async {
      TrackingRef.instance = TrackingRef();
      registered();
      await _pump(tester,
          form: const EventFormPage(eventId: 7, additionalDetails: []));

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final body = api
          .sent('POST', '/events/registration/7/register')
          .single
          .data as Map;
      expect(body.containsKey('ref'), isFalse);
    });
  });
}
