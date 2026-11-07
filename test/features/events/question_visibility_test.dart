// Conditional registration questions: the model and the one visibility
// algorithm (conditional-questions-contract.md §2, §3, §5), against the
// shared test form of §12.

import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/features/events/domain/question_visibility.dart';
import 'package:finnet/features/events/presentation/finish_payment.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conditional_form_fixture.dart';

List<String> _shownFor(Map<String, Object?> answers) =>
    visibleQuestions(sharedForm(), answers).map((q) => q.key).toList();

AdditionalDetail _q(String key, String type,
        {bool required = true,
        List<String> options = const [],
        QuestionCondition? showIf,
        bool? requiredWhenShown}) =>
    AdditionalDetail(
      key: key,
      label: key,
      fieldType: type,
      requiredField: required,
      options: options,
      showIf: showIf,
      requiredWhenShown: requiredWhenShown,
    );

void main() {
  group('the model', () {
    test('reads show_if and required_when_shown, keeping every field', () {
      final form = sharedForm();
      final college = form[1];
      expect(college.key, 'college');
      expect(college.label, 'College name');
      expect(college.fieldType, 'text');
      expect(college.requiredField, isFalse, reason: 'as sent, for old apps');
      expect(college.requiredWhenShown, isTrue);
      expect(college.requiredIfShown, isTrue);
      expect(college.showIf!.key, 'status');
      expect(college.showIf!.anyOf, ['Student']);

      final year = form[2];
      expect(year.options, ['1', '2', '3', '4']);
      expect(form[4].showIf!.key, 'degree_type');
      expect(form[4].showIf!.anyOf, ['PG']);
    });

    test('a question without show_if is read exactly as before', () {
      final status = sharedForm().first;
      expect(status.showIf, isNull);
      expect(status.requiredWhenShown, isNull);
      expect(status.requiredField, isTrue);
      expect(status.requiredIfShown, isTrue);
      expect(status.options, ['Student', 'Working']);

      final optional = AdditionalDetail.fromJson(const {
        'key': 'note',
        'label': 'Note',
        'field_type': 'text',
        'required': false,
        'show_if': null,
      });
      expect(optional.showIf, isNull);
      expect(optional.requiredIfShown, isFalse);

      // Not saying is required, as the server and the website read it.
      final unsaid = AdditionalDetail.fromJson(
          const {'key': 'x', 'label': 'X', 'field_type': 'text'});
      expect(unsaid.requiredIfShown, isTrue);
    });

    test('required_when_shown counts only with show_if', () {
      final stray = AdditionalDetail.fromJson(const {
        'key': 'x',
        'label': 'X',
        'field_type': 'text',
        'required': false,
        'required_when_shown': true,
      });
      expect(stray.requiredIfShown, isFalse);

      // Conditional, and the club left it optional.
      final optional = AdditionalDetail.fromJson(const {
        'key': 'x',
        'label': 'X',
        'field_type': 'text',
        'required': false,
        'required_when_shown': false,
        'show_if': {'key': 'status', 'any_of': ['Student']},
      });
      expect(optional.requiredIfShown, isFalse);

      // Conditional, from a server that sent only `required`.
      final older = AdditionalDetail.fromJson(const {
        'key': 'x',
        'label': 'X',
        'field_type': 'text',
        'required': true,
        'show_if': {'key': 'status', 'any_of': ['Student']},
      });
      expect(older.requiredIfShown, isTrue);
    });

    test('a show_if that names no question is no condition', () {
      for (final odd in [
        'status',
        {'any_of': ['Student']},
        {'key': '  ', 'any_of': ['Student']},
      ]) {
        final q = AdditionalDetail.fromJson(
            {'key': 'x', 'label': 'X', 'field_type': 'text', 'show_if': odd});
        expect(q.showIf, isNull, reason: '$odd');
      }
      final noValues = QuestionCondition.fromJson(const {'key': 'status'});
      expect(noValues!.anyOf, isEmpty);
    });
  });

  group('which questions are shown (the shared form)', () {
    test('nothing answered: the status and the T-shirt', () {
      expect(_shownFor(const {}), ['status', 'tshirt']);
    });

    test('Student + UG: 1-4 and 8; 5-7 hidden and not required', () {
      final answers = {
        'status': 'Student',
        'college': 'CET',
        'year': '2',
        'degree_type': 'UG',
        'tshirt': 'M',
      };
      expect(_shownFor(answers),
          ['status', 'college', 'year', 'degree_type', 'tshirt']);
      // pg_spec, company and experience are blank, and nothing is missing.
      expect(anyRequiredUnanswered(sharedForm(), answers), isFalse);
    });

    test('Student + PG: the nested question appears', () {
      expect(
          _shownFor(const {'status': 'Student', 'degree_type': 'PG'}),
          ['status', 'college', 'year', 'degree_type', 'pg_spec', 'tshirt']);
    });

    test('Working: 6-8; 2-5 hidden', () {
      expect(_shownFor(const {'status': 'Working'}),
          ['status', 'company', 'experience', 'tshirt']);
    });

    test("a child of a hidden question is hidden, whatever its parent's "
        'answer says', () {
      // PG, left over from the student path, under Working.
      expect(_shownFor(const {'status': 'Working', 'degree_type': 'PG'}),
          ['status', 'company', 'experience', 'tshirt']);
    });

    test('a blank or unknown answer reveals nothing', () {
      expect(_shownFor(const {'status': ''}), ['status', 'tshirt']);
      expect(_shownFor(const {'status': '  '}), ['status', 'tshirt']);
      expect(_shownFor(const {'status': 'Retired'}), ['status', 'tshirt']);
      expect(_shownFor(const {'status': 'student'}), ['status', 'tshirt'],
          reason: 'an exact match, as the server compares');
    });
  });

  group('answers that no longer apply', () {
    test('switching Student to Working drops the answers to 2-5', () {
      final answers = {...everyAnswer, 'status': 'Working'};
      expect(withoutHiddenAnswers(sharedForm(), answers), {
        'status': 'Working',
        'company': 'Acme',
        'experience': '3-5',
        'tshirt': 'M',
      });
    });

    test('switching PG to UG drops only question 5', () {
      final answers = {
        'status': 'Student',
        'college': 'CET',
        'year': '2',
        'degree_type': 'UG',
        'pg_spec': 'Data science',
        'tshirt': 'M',
      };
      expect(withoutHiddenAnswers(sharedForm(), answers), {
        'status': 'Student',
        'college': 'CET',
        'year': '2',
        'degree_type': 'UG',
        'tshirt': 'M',
      });
    });

    test('every question answered (an old app): only the path chosen is kept',
        () {
      expect(withoutHiddenAnswers(sharedForm(), everyAnswer), {
        'status': 'Student',
        'college': 'CET',
        'year': '2',
        'degree_type': 'PG',
        'pg_spec': 'Data science',
        'tshirt': 'M',
      });
    });

    test('an answer to something the form does not ask is left alone', () {
      expect(withoutHiddenAnswers(sharedForm(), const {'extra': 'x'}),
          {'extra': 'x'});
    });
  });

  group('required only when shown', () {
    test('a shown, blank, required follow-up is missing', () {
      expect(
          anyRequiredUnanswered(sharedForm(), const {
            'status': 'Student',
            'year': '2',
            'degree_type': 'UG',
            'tshirt': 'M',
          }),
          isTrue,
          reason: 'college is shown and blank');
    });

    test('a hidden one is never required', () {
      expect(
          anyRequiredUnanswered(sharedForm(), const {
            'status': 'Working',
            'company': 'Acme',
            'experience': '0-2',
            'tshirt': 'S',
          }),
          isFalse);
    });

    test('the nested one is required once PG is picked', () {
      final answers = {
        'status': 'Student',
        'college': 'CET',
        'year': '2',
        'degree_type': 'PG',
        'tshirt': 'M',
      };
      expect(anyRequiredUnanswered(sharedForm(), answers), isTrue);
      expect(
          anyRequiredUnanswered(
              sharedForm(), {...answers, 'pg_spec': 'Data science'}),
          isFalse);
    });

    test('the form is needed before paying only for what everyone answers',
        () {
      // The shared form asks everyone their status.
      expect(
          FinishPayment.needsForm(
              questions: sharedForm(), name: 'Asha Menon', email: 'a@b.co'),
          isTrue);
      // Only follow-ups are required, under an optional question: an empty
      // form is complete.
      final followUpsOnly = [
        _q('status', 'radio', required: false, options: ['Student', 'Working']),
        _q('college', 'text',
            required: false,
            requiredWhenShown: true,
            showIf:
                const QuestionCondition(key: 'status', anyOf: ['Student'])),
      ];
      expect(
          FinishPayment.needsForm(
              questions: followUpsOnly, name: 'Asha Menon', email: 'a@b.co'),
          isFalse);
    });
  });

  group('matching an answer (exact, as moa_web visibility.ts)', () {
    test('a one-choice answer: one of any_of', () {
      expect(conditionMatches('Student', ['Student']), isTrue);
      expect(conditionMatches('Working', ['Student']), isFalse);
      expect(conditionMatches('Working', ['Student', 'Working']), isTrue);
      expect(conditionMatches(2, ['2']), isTrue, reason: 'its text form');
    });

    test('ticks: any one of them in any_of, as a list or one string', () {
      expect(conditionMatches(['AI', 'Web'], ['Web']), isTrue);
      expect(conditionMatches(['AI'], ['Web', 'Hardware']), isFalse);
      expect(conditionMatches('Web', ['Web']), isTrue);
    });

    test('compared exactly: no trimming, case counts', () {
      expect(conditionMatches('student', ['Student']), isFalse);
      expect(conditionMatches('Student ', ['Student']), isFalse);
      expect(conditionMatches(' Student', ['Student']), isFalse);
      expect(conditionMatches(['Web '], ['Web']), isFalse);
    });

    test('a blank answer: never', () {
      for (final blank in [null, '', '   ', <String>[], [''], ['', ' ']]) {
        expect(conditionMatches(blank, ['Student', '', '   ']), isFalse,
            reason: '$blank');
      }
    });

    test('a checkbox parent reveals through any of its ticks', () {
      final form = [
        _q('diet', 'checkbox', options: ['Veg', 'Jain', 'Vegan']),
        _q('notes', 'text',
            showIf: const QuestionCondition(
                key: 'diet', anyOf: ['Jain', 'Vegan'])),
      ];
      expect(visibleQuestionKeys(form, const {'diet': ['Veg']}), {'diet'});
      expect(visibleQuestionKeys(form, const {'diet': ['Veg', 'Vegan']}),
          {'diet', 'notes'});
    });
  });

  group('a definition the server would refuse', () {
    test('a parent after its child, or missing, never shows the child', () {
      final childFirst = [
        _q('college', 'text',
            showIf:
                const QuestionCondition(key: 'status', anyOf: ['Student'])),
        _q('status', 'radio', options: ['Student', 'Working']),
      ];
      expect(visibleQuestionKeys(childFirst, const {'status': 'Student'}),
          {'status'});

      final orphan = [
        _q('college', 'text',
            showIf: const QuestionCondition(key: 'gone', anyOf: ['x'])),
      ];
      expect(visibleQuestionKeys(orphan, const {'gone': 'x'}), isEmpty);
    });

    test('a question that depends on itself, or on nothing, stays hidden', () {
      final self = [
        _q('a', 'radio',
            options: ['x'],
            showIf: const QuestionCondition(key: 'a', anyOf: ['x'])),
        _q('b', 'text',
            showIf: const QuestionCondition(key: 'a', anyOf: [])),
      ];
      expect(visibleQuestionKeys(self, const {'a': 'x'}), isEmpty);
    });

    test('nesting five deep still resolves in one pass', () {
      final chain = [
        _q('l0', 'radio', options: ['y']),
        for (var i = 1; i <= 5; i++)
          _q('l$i', 'radio',
              options: ['y'],
              showIf: QuestionCondition(key: 'l${i - 1}', anyOf: ['y'])),
      ];
      final all = {for (var i = 0; i <= 5; i++) 'l$i': 'y'};
      expect(visibleQuestionKeys(chain, all).length, 6);
      expect(visibleQuestionKeys(chain, {...all, 'l2': 'n'}),
          {'l0', 'l1', 'l2'});
    });
  });

  group('an unconditional form', () {
    test('every question is shown and every answer kept', () {
      final form = [
        _q('a', 'text'),
        _q('b', 'select', required: false, options: ['x', 'y']),
        _q('c', 'checkbox', options: ['I agree']),
      ];
      expect(visibleQuestions(form, const {}).map((q) => q.key),
          ['a', 'b', 'c']);
      const answers = {'a': 'hi', 'b': 'x', 'c': 'I agree'};
      expect(withoutHiddenAnswers(form, answers), answers);
      expect(anyRequiredUnanswered(form, const {}), isTrue);
      expect(anyRequiredUnanswered(form, answers), isFalse);
    });
  });

  group('what a screen reader hears', () {
    final form = sharedForm();
    List<AdditionalDetail> shown(Map<String, Object?> a) =>
        visibleQuestions(form, a);

    test('the questions that appeared, by name', () {
      expect(
          visibilityChangeAnnouncement(
              shown(const {}), shown(const {'status': 'Working'})),
          '2 new questions: Company, Years of experience.');
      expect(
          visibilityChangeAnnouncement(
              shown(const {'status': 'Student'}),
              shown(const {'status': 'Student', 'degree_type': 'PG'})),
          'New question: PG specialisation.');
    });

    test('and how many went', () {
      expect(
          visibilityChangeAnnouncement(
              shown(const {'status': 'Student', 'degree_type': 'PG'}),
              shown(const {'status': 'Working'})),
          '2 new questions: Company, Years of experience. '
          '4 questions removed.');
      expect(
          visibilityChangeAnnouncement(
              shown(const {'status': 'Student', 'degree_type': 'PG'}),
              shown(const {'status': 'Student', 'degree_type': 'UG'})),
          '1 question removed.');
    });

    test('nothing when nothing changed', () {
      expect(
          visibilityChangeAnnouncement(shown(const {'status': 'Student'}),
              shown(const {'status': 'Student', 'year': '2'})),
          isNull);
    });
  });
}
