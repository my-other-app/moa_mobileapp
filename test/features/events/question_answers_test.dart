import 'package:finnet/features/events/presentation/utils/question_answers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('questions', () {
    test('dates and times are picked; choices are boxes', () {
      expect(questionControlOf('date'), QuestionControl.date);
      expect(questionControlOf('time'), QuestionControl.time);
      expect(questionControlOf('datetime'), QuestionControl.dateTime);
      expect(questionControlOf('checkbox'), QuestionControl.checkbox);
      expect(questionControlOf('radio'), QuestionControl.radio);
      expect(questionControlOf('select'), QuestionControl.select);
      expect(questionControlOf('textarea'), QuestionControl.text);
      // Unknown types stay a text box rather than vanishing.
      expect(questionControlOf('file'), QuestionControl.text);
      expect(questionControlOf(''), QuestionControl.text);
    });

    test("answers go in the website's formats", () {
      final m = DateTime(2026, 3, 7, 9, 5);
      expect(dateAnswer(m), '2026-03-07');
      expect(timeAnswer(9, 5), '09:05');
      expect(dateTimeAnswer(m), '2026-03-07T09:05');
      expect(dateLabel(m), '7 Mar 2026');
      expect(timeLabel(21, 5), '9:05 PM');
      expect(dateTimeLabel(m), '7 Mar 2026, 9:05 AM');
    });

    test('a checkbox without options is a single "Yes" box', () {
      expect(checkboxValues(const []), ['Yes']);
      expect(checkboxValues(const ['I agree']), ['I agree']);
      expect(checkboxValues(const ['Veg', ' ', 'Non-veg']), ['Veg', 'Non-veg']);
    });
  });
}
