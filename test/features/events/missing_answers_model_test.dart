// "Missing answers" (feature-register missing-answers-contract.md): what the
// app reads of the server's words, read defensively -- an older server sends
// none of it, and nothing changes.

import 'dart:io';

import 'package:dio/dio.dart';

import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/features/events/domain/missing_answers.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/providers/ticket_details_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/widgets/question_fields.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/domain/door_answers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conditional_form_fixture.dart';
import 'events_fakes.dart';

const _link = 'https://myotherapp.in/answers/12/reg-1?k=abc.def';

void main() {
  group('answers_needed', () {
    test('a note with its count, link and deadline', () {
      final needed = AnswersNeeded.fromJson({
        'count': 2,
        'url': _link,
        'deadline': '2026-11-14T12:30:00Z',
      })!;
      expect(needed.count, 2);
      expect(needed.url, _link);
      expect(needed.line, '2 details needed · Add them');
      expect(needed.byLine, startsWith('By '));
      expect(
          needed.deadline!.isAtSameMomentAs(DateTime.utc(2026, 11, 14, 12, 30)),
          isTrue);
    });

    test('one detail reads as one', () {
      final needed = AnswersNeeded.fromJson({'count': 1, 'url': _link})!;
      expect(needed.line, '1 detail needed · Add it');
      expect(needed.byLine, isNull);
    });

    test('nothing asked, no link, or an older server: no note', () {
      expect(AnswersNeeded.fromJson(null), isNull);
      expect(AnswersNeeded.fromJson('yes'), isNull);
      expect(AnswersNeeded.fromJson(const {'count': 2}), isNull);
      expect(AnswersNeeded.fromJson(const {'count': 2, 'url': '  '}), isNull);
      expect(AnswersNeeded.fromJson(const {'count': 0, 'url': _link}), isNull);
      // A count that is not said still asks.
      expect(AnswersNeeded.fromJson(const {'url': _link})!.line,
          'Details needed · Add them');
    });

    test('is read off a ticket, a registration row and a request', () {
      const flag = {'count': 2, 'url': _link, 'deadline': null};
      expect(
          TicketDetails.of({'ticket_revoked': false, 'answers_needed': flag})!
              .answersNeeded!
              .count,
          2);
      expect(
          TicketDetails.of({'ticket_revoked': false})!.answersNeeded, isNull);

      final card = eventCardFromJson({
        'id': 12,
        'name': 'Hack Night',
        'club': {'id': 1, 'name': 'Tinkerhub'},
        'answers_needed': flag,
      });
      expect(card.answersNeeded!.url, _link);
      expect(eventCardFromJson({'id': 12}).answersNeeded, isNull);

      final request = RegistrationRequest.fromJson({
        'id': 'r-1',
        'status': 'pending',
        'token': 'tok',
        'answers_needed': flag,
      })!;
      expect(request.answersNeeded!.count, 2);
      // Read again, the server's word is the one kept: answered, it goes.
      final fresh = RegistrationRequest.fromJson(
          {'id': 'r-1', 'status': 'pending', 'token': 'tok'})!;
      expect(request.mergedWith(fresh).answersNeeded, isNull);
    });
  });

  group('the personal link', () {
    test('is the app\'s own screen, key and all', () {
      expect(answersRouteFrom(_link), '/answers/12/reg-1?k=abc.def');
      expect(answersRouteFrom('https://myotherapp.in/answers/12/qabc'),
          '/answers/12/qabc');
      expect(answersRoute(12, 'reg-1', key: 'k1'), '/answers/12/reg-1?k=k1');
    });

    test('anything else is not', () {
      expect(answersRouteFrom(null), isNull);
      expect(answersRouteFrom(''), isNull);
      expect(answersRouteFrom('https://myotherapp.in/events/12'), isNull);
      expect(answersRouteFrom('https://myotherapp.in/answers/x/reg-1'), isNull);
      expect(answersRouteFrom('https://myotherapp.in/answers/12'), isNull);
      expect(answersRouteFrom('mailto:answers/12/reg'), isNull);
    });

    test('Android opens it in the app', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:pathPrefix="/answers/"'));
    });
  });

  group('the screen\'s words (GET /events/{id}/answers/{ref})', () {
    test('are read in full', () {
      final form = AnswersForm.fromJson({
        'status': 'open',
        'event': {
          'id': 12,
          'name': 'Hack Night',
          'starts_at': '2026-12-01T10:00:00Z',
          'org_name': 'Tinkerhub',
          'poster': 'https://cdn.example/p.jpg',
          'slug': 'hack-night-ab12cd',
        },
        'person': {'first_name': 'Haritha', 'kind': 'request'},
        'deadline': '2026-11-28T12:30:00Z',
        'message': 'We need 2 more details.',
        'questions': sharedFormJson,
        // Out of order, once twice, and a key the form doesn't have.
        'asked': ['tshirt', 'year', 'year', 'gone'],
        'answers': {'status': 'Student'},
        'ticket_url': null,
        'request_url': 'https://myotherapp.in/requests/tok-1',
      });
      expect(form.status, AnswersStatus.open);
      expect(form.event.name, 'Hack Night');
      expect(form.event.route, '/events/hack-night-ab12cd');
      expect(form.firstName, 'Haritha');
      expect(form.isRequest, isTrue);
      expect(form.questions, hasLength(8));
      expect(form.asked, ['year', 'tshirt']);
      expect(form.answers, {'status': 'Student'});
      expect(form.ticketUrl, isNull);
      expect(form.requestUrl, 'https://myotherapp.in/requests/tok-1');
      expect(form.clubName, 'Tinkerhub');
    });

    test('every status, and an unknown one', () {
      for (final (word, status) in [
        ('open', AnswersStatus.open),
        ('done', AnswersStatus.done),
        ('closed', AnswersStatus.closed),
        ('nothing', AnswersStatus.nothing),
        ('later', AnswersStatus.unknown),
      ]) {
        expect(AnswersForm.fromJson({'status': word}).status, status);
      }
      final empty = AnswersForm.fromJson(null, fallbackEventId: 7);
      expect(empty.event.id, 7);
      expect(empty.asked, isEmpty);
    });
  });

  group('what an ask shows (conditional-questions-contract.md §3)', () {
    test('the questions asked, and the follow-ups each brings', () {
      final form = sharedForm();
      expect(askedWithFollowUps(form, ['degree_type']),
          {'degree_type', 'pg_spec'});
      expect(askedWithFollowUps(form, ['tshirt']), {'tshirt'});
      expect(askedWithFollowUps(form, ['status']), {
        'status',
        'college',
        'year',
        'degree_type',
        'pg_spec',
        'company',
        'experience',
      });
    });

    test('filled in with what they have: a choice only while it is one', () {
      final fields = QuestionAnswers()
        ..setQuestions(sharedForm(), only: {'year', 'tshirt', 'college'})
        ..prefill({
          'status': 'Student',
          'college': 'CET',
          'year': 2, // A number, as JSON may carry it.
          'tshirt': 'XXL', // Removed by the club since.
        }, only: {
          'year',
          'tshirt',
          'college'
        });
      addTearDown(fields.dispose);
      expect(fields.choices['year'], '2');
      expect(fields.choices.containsKey('tshirt'), isFalse);
      expect(fields.texts['college']!.text, 'CET');
      // Not asked: nothing of it on the form.
      expect(fields.choices.containsKey('status'), isFalse);
    });

    test('what they answered elsewhere decides what shows, and is not sent',
        () {
      final fields = QuestionAnswers()
        ..setQuestions(sharedForm(), only: {'degree_type', 'pg_spec'})
        ..given = {'status': 'Student'};
      addTearDown(fields.dispose);
      expect(fields.shownKeys, containsAll(['degree_type', 'tshirt']));
      expect(fields.shownKeys.contains('pg_spec'), isFalse);

      fields.choose(sharedForm()[3], 'PG');
      expect(fields.shownKeys, contains('pg_spec'));
      fields.texts['pg_spec']!.text = 'Data science';
      expect(
          fields.collect(), {'degree_type': 'PG', 'pg_spec': 'Data science'});

      // PG to UG: the nested answer goes.
      fields.choose(sharedForm()[3], 'UG');
      expect(fields.texts['pg_spec']!.text, isEmpty);
      expect(fields.collect(), {'degree_type': 'UG'});
    });

    test('a date, a time and a moment are picked again from what was sent', () {
      AdditionalDetail asked(String key, String type) => AdditionalDetail(
          key: key,
          label: key,
          fieldType: type,
          requiredField: true,
          options: const []);
      final fields = QuestionAnswers()
        ..setQuestions([
          asked('day', 'date'),
          asked('at', 'time'),
          asked('when', 'datetime-local'),
          asked('odd', 'date'),
        ])
        ..prefill({
          'day': '2026-10-18',
          'at': '09:05',
          'when': '2026-10-18T09:05',
          'odd': 'next Tuesday',
        });
      addTearDown(fields.dispose);
      expect(fields.collect(), {
        'day': '2026-10-18',
        'at': '09:05',
        'when': '2026-10-18T09:05',
      });
      expect(fields.texts['day']!.text, '18 Oct 2026');
      expect(fields.texts['odd']!.text, isEmpty);
    });
  });

  group('at the door', () {
    test('a guest\'s missing answers are read; none from an older server', () {
      final guest = GateAttendee.fromJson({
        'id': 'reg-1',
        'name': 'Asha',
        'ticket_id': 'MOA-1',
        'missing_answers': [
          {'key': 'tshirt', 'label': 'T-shirt size'},
          {'key': 'why'},
          'college',
          {'label': 'no key'},
        ],
      })!;
      expect(guest.missingAnswers, const [
        MissingAnswer(key: 'tshirt', label: 'T-shirt size'),
        MissingAnswer(key: 'why', label: 'why'),
        MissingAnswer(key: 'college', label: 'college'),
      ]);
      expect(missingLabels(guest.missingAnswers), 'T-shirt size, why, college');
      expect(
          GateAttendee.fromJson({'id': 'reg-2', 'name': 'B'})!.missingAnswers,
          isEmpty);
      expect(guest.withMissingAnswers(const []).missingAnswers, isEmpty);
      expect(guest.withMissingAnswers(const []).name, 'Asha');
    });

    test('the console reads the form it fills them in with', () {
      final context = GateContext.fromJson({
        'event': {'id': 7, 'name': 'Hack Night'},
        'guest_fields': sharedFormJson,
      });
      expect(context.guestFields, hasLength(8));
      expect(context.withCheckedIn(3).guestFields, hasLength(8));
      expect(
          GateContext.fromJson({
            'event': {'id': 7}
          }).guestFields,
          isEmpty);
    });

    test('filled in at the door: POST /gate/answers/{reg}, and what is left',
        () async {
      final server = RouteAdapter()
        ..on('POST', '/events/7/gate/answers/reg-1', {
          'missing_answers': [
            {'key': 'why', 'label': 'Why are you coming?'},
          ],
        });
      final still = await GateApi(Dio()..httpClientAdapter = server)
          .saveAnswers(7, 'reg-1', {'tshirt': 'M'});
      expect(server.sent('POST', '/events/7/gate/answers/reg-1').single.data, {
        'answers': {'tshirt': 'M'},
      });
      expect(still,
          const [MissingAnswer(key: 'why', label: 'Why are you coming?')]);
    });

    test(
        'the questions: the missing ones always shown, none required, '
        'their follow-ups by what is chosen', () {
      final questions = doorQuestions(sharedForm(), const [
        MissingAnswer(key: 'degree_type', label: 'Degree type'),
        MissingAnswer(key: 'tshirt', label: 'T-shirt size'),
        MissingAnswer(key: 'gone', label: 'A question since removed'),
      ]);
      expect(questions.map((q) => q.key),
          ['degree_type', 'pg_spec', 'tshirt', 'gone']);
      expect(questions.every((q) => !q.requiredIfShown), isTrue);
      // Missing, so it applies: shown whatever the door knows of status.
      expect(questions[0].showIf, isNull);
      expect(questions[1].showIf?.key, 'degree_type');
      expect(questions[3].fieldType, 'text');
      expect(questions[3].label, 'A question since removed');
      expect(missingCount(1), '1 detail missing');
      expect(missingCount(3), '3 details missing');
    });
  });
}
