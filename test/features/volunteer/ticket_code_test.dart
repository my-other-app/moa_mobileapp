import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/data/ticket_code.dart';
import 'package:finnet/features/volunteer/data/ticket_refusal.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/domain/repositories/volunteer_repository.dart';
import 'package:finnet/features/volunteer/presentation/pages/manual_ticket_entry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server's answer to a code that names no ticket on this event --
/// which, from fix/wave1 on, includes every admission number
/// (app/api/events/volunteer/service.py).
const _notFound = ApiException(
  message: 'Registration not found',
  statusCode: 400,
  type: ApiExceptionType.badRequest,
  serverMessage: 'Registration not found',
  errorCode: 'REGISTRATION_NOT_FOUND',
);

class _Repository implements VolunteerRepository {
  _Repository(this.answer);

  final Object answer;
  final List<String> checkins = [];

  @override
  Future<Result<List<VolunteerEvent>>> myEvents() async => Either.right([]);

  @override
  Future<CheckinResult> validate(int eventId, String ticketId) =>
      checkin(eventId, ticketId);

  @override
  Future<CheckinResult> checkin(int eventId, String ticketId) async {
    checkins.add(ticketId);
    final answer = this.answer;
    if (answer is CheckinResult) return answer;
    return classifyRefusal(answer, entered: ticketId);
  }
}

void main() {
  group('what a typed code looks like', () {
    test('ticket codes, new and old, and registration ids', () {
      expect(looksLikeTicketCode(ticketCodeExample), isTrue);
      expect(looksLikeTicketCode(' moa-7k3qf-x9pwm '), isTrue);
      // Older tickets: MOA-, the time in hex, five letters.
      expect(looksLikeTicketCode('MOA-3F2A9C-K7QXD'), isTrue);
      expect(looksLikeTicketCode('MOA-1A-K7QXD'), isTrue);
      expect(
          looksLikeTicketCode('0b7c2a3e-5d4f-4a8e-9c1b-2f3e4d5a6b7c'), isTrue);

      expect(looksLikeTicketCode('MOA-0042-E12'), isFalse);
      expect(looksLikeTicketCode('hello'), isFalse);
    });

    test('admission numbers, in every shape an event can give them', () {
      expect(looksLikeAdmissionNumber('MOA-0042-E12'), isTrue);
      expect(looksLikeAdmissionNumber('moa-0042-e12'), isTrue);
      expect(looksLikeAdmissionNumber('MOA-0042'), isTrue); // no event code
      expect(looksLikeAdmissionNumber('TEDX-KOCHI-00042-E7'), isTrue);
      expect(looksLikeAdmissionNumber('MOA-12345-E1234'), isTrue);
      expect(looksLikeAdmissionNumber('A12-E7'), isTrue); // a seat
    });

    test('a ticket code is never taken for an admission number', () {
      expect(looksLikeAdmissionNumber(ticketCodeExample), isFalse);
      // All digits in the middle, as a new code can be.
      expect(looksLikeAdmissionNumber('MOA-23456-X9PWM'), isFalse);
      // An old code whose last group reads like an event code.
      expect(looksLikeAdmissionNumber('MOA-3F2A9C-E2345'), isFalse);
      expect(looksLikeAdmissionNumber('hello'), isFalse);
      expect(looksLikeAdmissionNumber(''), isFalse);
    });
  });

  group('a code that names no ticket', () {
    test('an admission number is told the ticket code is needed', () {
      final r = classifyRefusal(_notFound, entered: 'moa-0042-e12');

      expect(r.type, CheckinResultType.notFound);
      expect(r.message, contains('MOA-0042-E12 is an admission number'));
      expect(r.message, contains('ticket code'));
      expect(r.message, contains(ticketCodeExample));
    });

    test('so is one from a server without codes', () {
      const prose = ApiException(
        message: 'Registration not found',
        statusCode: 400,
        type: ApiExceptionType.badRequest,
        serverMessage: 'Registration not found',
      );

      final r = classifyRefusal(prose, entered: 'MOA-0042-E12');

      expect(r.message, contains('admission number'));
    });

    test('a mistyped ticket code is asked to be checked', () {
      final r = classifyRefusal(_notFound, entered: 'MOA-7K3QF-X9PWN');

      expect(r.type, CheckinResultType.notFound);
      expect(r.message, contains('No ticket matches MOA-7K3QF-X9PWN'));
      expect(r.message, isNot(contains('admission')));
    });

    test('other refusals of an admission-shaped code keep their own words',
        () {
      const used = ApiException(
        message: 'User already checked-in',
        statusCode: 400,
        type: ApiExceptionType.badRequest,
        serverMessage: 'User already checked-in',
        errorCode: 'TICKET_ALREADY_USED',
      );

      final r = classifyRefusal(used, entered: 'MOA-0042-E12');

      expect(r.type, CheckinResultType.alreadyScanned);
      expect(r.message, 'User already checked-in');
    });

    test('a missing event is not a missing ticket', () {
      const noEvent = ApiException(
        message: 'Event not found',
        statusCode: 404,
        type: ApiExceptionType.notFound,
        serverMessage: 'Event not found',
        errorCode: 'EVENT_NOT_FOUND',
      );

      final r = classifyRefusal(noEvent, entered: 'MOA-0042-E12');

      expect(r.message, 'Event not found');
    });
  });

  group('the manual entry page', () {
    Future<_Repository> pump(WidgetTester tester, Object answer) async {
      final repository = _Repository(answer);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          volunteerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: ManualTicketEntryPage(
            eventId: 7,
            eventName: 'Hack Night',
            clubName: 'Code Club',
          ),
        ),
      ));
      return repository;
    }

    testWidgets('asks for the ticket code', (tester) async {
      await pump(tester, _notFound);

      expect(find.text('Ticket code'), findsOneWidget);
      expect(find.text('e.g. $ticketCodeExample'), findsOneWidget);
      expect(find.textContaining("Admission numbers like MOA-0042-E12 can't"),
          findsOneWidget);
      expect(find.textContaining('Ticket ID'), findsOneWidget);
      expect(find.text('ACCESS EVENT USING TICKET ID'), findsNothing);
    });

    testWidgets('an admission number is refused with why, under the field',
        (tester) async {
      final repository = await pump(tester, _notFound);

      await tester.enterText(find.byType(TextFormField), 'MOA-0042-E12');
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(repository.checkins, ['MOA-0042-E12']);
      expect(find.textContaining('MOA-0042-E12 is an admission number'),
          findsOneWidget);

      // Typing again clears it, back to the hint.
      await tester.enterText(find.byType(TextFormField), 'MOA-7K3QF');
      await tester.pump();
      expect(find.textContaining('is an admission number'), findsNothing);
    });

    testWidgets('an empty field asks for the code and sends nothing',
        (tester) async {
      final repository = await pump(tester, _notFound);

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(find.text('Enter the ticket code'), findsOneWidget);
      expect(repository.checkins, isEmpty);
    });

    testWidgets('a good code checks in and clears the field', (tester) async {
      await pump(
        tester,
        const CheckinResult(
          success: true,
          type: CheckinResultType.success,
          message: 'Check-in successful!',
        ),
      );

      await tester.enterText(find.byType(TextFormField), ticketCodeExample);
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(find.text('Check-in successful!'), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller
              ?.text,
          isEmpty);
    });
  });
}
